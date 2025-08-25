#!/bin/bash

echo "🧹 AI Quotation Processor - Resource Cleanup"
echo "============================================="

PROJECT_NAME="quotation-processor"
PROJECT_NAME_FINAL="quotation-processor-final"
REGION="us-east-1"

echo "⚠️  This will delete ALL resources created by deploy-all.sh"
echo "Are you sure you want to continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo "🗑️  Starting cleanup process..."

# Step 1: Disable CloudFront distributions
echo "📡 Step 1/7: Disabling CloudFront distributions..."
for dist_id in $(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${PROJECT_NAME} frontend'].Id" --output text --region $REGION); do
    if [ ! -z "$dist_id" ]; then
        echo "Disabling CloudFront distribution: $dist_id"
        etag=$(aws cloudfront get-distribution --id $dist_id --query "ETag" --output text)
        aws cloudfront get-distribution-config --id $dist_id --query "DistributionConfig" > temp-config.json
        sed -i 's/"Enabled": true/"Enabled": false/' temp-config.json
        aws cloudfront update-distribution --id $dist_id --distribution-config file://temp-config.json --if-match $etag > /dev/null
        rm temp-config.json
    fi
done

# Step 2: Delete API Gateway
echo "🌐 Step 2/7: Deleting API Gateway..."
for api_id in $(aws apigateway get-rest-apis --query "items[?name=='${PROJECT_NAME}-api'].id" --output text --region $REGION); do
    if [ ! -z "$api_id" ]; then
        echo "Deleting API Gateway: $api_id"
        aws apigateway delete-rest-api --rest-api-id $api_id --region $REGION
    fi
done

for api_id in $(aws apigateway get-rest-apis --query "items[?name=='${PROJECT_NAME_FINAL}-api'].id" --output text --region $REGION); do
    if [ ! -z "$api_id" ]; then
        echo "Deleting API Gateway: $api_id"
        aws apigateway delete-rest-api --rest-api-id $api_id --region $REGION
    fi
done

# Step 3: Delete Lambda functions and layers
echo "⚡ Step 3/7: Deleting Lambda functions and layers..."
aws lambda delete-function --function-name ${PROJECT_NAME}-processor --region $REGION 2>/dev/null
aws lambda delete-function --function-name ${PROJECT_NAME_FINAL}-processor --region $REGION 2>/dev/null

for layer_arn in $(aws lambda list-layers --query "Layers[?LayerName=='${PROJECT_NAME}-pdf-layer'].LatestMatchingVersion.LayerVersionArn" --output text --region $REGION); do
    if [ ! -z "$layer_arn" ]; then
        layer_name=$(echo $layer_arn | cut -d: -f7)
        version=$(echo $layer_arn | cut -d: -f8)
        echo "Deleting Lambda layer: $layer_name version $version"
        aws lambda delete-layer-version --layer-name $layer_name --version-number $version --region $REGION
    fi
done

for layer_arn in $(aws lambda list-layers --query "Layers[?LayerName=='${PROJECT_NAME_FINAL}-pdf-layer'].LatestMatchingVersion.LayerVersionArn" --output text --region $REGION); do
    if [ ! -z "$layer_arn" ]; then
        layer_name=$(echo $layer_arn | cut -d: -f7)
        version=$(echo $layer_arn | cut -d: -f8)
        echo "Deleting Lambda layer: $layer_name version $version"
        aws lambda delete-layer-version --layer-name $layer_name --version-number $version --region $REGION
    fi
done

# Step 4: Empty and delete S3 buckets
echo "🗜️  Step 4/7: Emptying and deleting S3 buckets..."
for bucket in $(aws s3api list-buckets --query "Buckets[?starts_with(Name, '${PROJECT_NAME}')].Name" --output text); do
    if [ ! -z "$bucket" ]; then
        echo "Emptying bucket: $bucket"
        aws s3 rm s3://$bucket --recursive --quiet
        echo "Deleting bucket: $bucket"
        aws s3api delete-bucket --bucket $bucket --region $REGION
    fi
done

# Step 5: Delete DynamoDB table
echo "📊 Step 5/7: Deleting DynamoDB table..."
aws dynamodb delete-table --table-name ${PROJECT_NAME}-quotations --region $REGION 2>/dev/null
aws dynamodb delete-table --table-name ${PROJECT_NAME_FINAL}-quotations --region $REGION 2>/dev/null

# Step 6: Delete IAM role and policies
echo "🔐 Step 6/7: Deleting IAM role and policies..."
aws iam delete-role-policy --role-name ${PROJECT_NAME}-role --policy-name ${PROJECT_NAME}-policy 2>/dev/null
aws iam delete-role-policy --role-name ${PROJECT_NAME}-role --policy-name bedrock-prompt-policy 2>/dev/null
aws iam delete-role --role-name ${PROJECT_NAME}-role 2>/dev/null

aws iam delete-role-policy --role-name ${PROJECT_NAME_FINAL}-role --policy-name ${PROJECT_NAME_FINAL}-policy 2>/dev/null
aws iam delete-role-policy --role-name ${PROJECT_NAME_FINAL}-role --policy-name bedrock-prompt-policy 2>/dev/null
aws iam delete-role --role-name ${PROJECT_NAME_FINAL}-role 2>/dev/null

# Step 7: Delete Bedrock prompts
echo "🧠 Step 7/7: Deleting Bedrock prompts..."
for prompt_id in $(aws bedrock-agent list-prompts --query "promptSummaries[?name=='${PROJECT_NAME}-prompt'].id" --output text --region $REGION); do
    if [ ! -z "$prompt_id" ]; then
        echo "Deleting Bedrock prompt: $prompt_id"
        aws bedrock-agent delete-prompt --prompt-identifier $prompt_id --region $REGION 2>/dev/null
    fi
done

echo "✅ Cleanup completed!"
echo ""
echo "Note: CloudFront distributions have been disabled but not deleted."
echo "They will be automatically deleted after 24 hours of being disabled."
echo "You can manually delete them from the AWS Console if needed."