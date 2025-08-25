#!/bin/bash

echo "🔧 Quick Fix: Rebuilding Lambda Layer with fpdf2"
echo "=============================================="

PROJECT_NAME="quotation-processor-final"
REGION="us-east-1"

# Clean up any existing layer directory
rm -rf lambda-layer pdf-layer.zip

# Create fresh layer directory
mkdir -p lambda-layer/python
cd lambda-layer/python

echo "📦 Installing fpdf2 and dependencies..."

# Install fpdf2 with all its dependencies
pip install fpdf2==2.7.6 --target . --no-cache-dir

# Install other required libraries
pip install PyPDF2==3.0.1 --target . --no-cache-dir
pip install Pillow==10.1.0 --target . --no-cache-dir

echo "✅ Installed packages:"
ls -la | grep -E "(fpdf|PIL|PyPDF)"

cd ../..

# Create the layer zip
echo "📦 Creating layer zip..."
cd lambda-layer
zip -r ../pdf-layer.zip python -q
cd ..

# Publish new layer version
echo "🚀 Publishing new layer version..."
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name ${PROJECT_NAME}-pdf-layer \
    --zip-file fileb://pdf-layer.zip \
    --compatible-runtimes python3.11 \
    --region $REGION \
    --profile gikensakata \
    --query "LayerVersionArn" \
    --output text)

echo "New Layer ARN: $LAYER_ARN"

# Update Lambda function with new layer
echo "⚡ Updating Lambda function..."
aws lambda update-function-configuration \
    --function-name ${PROJECT_NAME}-processor \
    --layers $LAYER_ARN \
    --region $REGION \
    --profile gikensakata

# Clean up
rm -rf lambda-layer pdf-layer.zip

echo ""
echo "✅ FIXED! The fpdf2 module should now be available."
echo "🧪 Test your quotation processor again."
echo ""
echo "If you still get errors, the issue might be:"
echo "1. Import path in Lambda runtime"
echo "2. Python version compatibility"
echo "3. Missing system dependencies"
