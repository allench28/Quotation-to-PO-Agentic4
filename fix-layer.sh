#!/bin/bash

echo "🔧 Fixing Lambda Layer - Adding missing fpdf library"
echo "===================================================="

PROJECT_NAME="quotation-processor-final"
REGION="us-east-1"

# Create temporary directory for layer
echo "📦 Creating Lambda layer with required libraries..."
mkdir -p lambda-layer/python
cd lambda-layer/python

# Install all required libraries
echo "Installing Python libraries..."
pip install fpdf2==2.7.6 fontTools==4.47.0 Pillow==10.1.0 defusedxml PyPDF2==3.0.1 -t . --quiet --no-deps

# Also install dependencies that might be missing
pip install typing-extensions==4.8.0 -t . --quiet --no-deps

echo "Libraries installed:"
ls -la

cd ../..

# Create layer zip
echo "📦 Creating layer zip file..."
cd lambda-layer
zip -r ../pdf-layer-fixed.zip python
cd ..

# Publish new layer version
echo "🚀 Publishing new layer version..."
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name ${PROJECT_NAME}-pdf-layer \
    --zip-file fileb://pdf-layer-fixed.zip \
    --compatible-runtimes python3.11 \
    --region $REGION \
    --profile gikensakata \
    --query "LayerVersionArn" \
    --output text)

echo "New layer ARN: $LAYER_ARN"

# Update Lambda function to use new layer
echo "⚡ Updating Lambda function with new layer..."
aws lambda update-function-configuration \
    --function-name ${PROJECT_NAME}-processor \
    --layers $LAYER_ARN \
    --region $REGION \
    --profile gikensakata

# Clean up
rm -rf lambda-layer pdf-layer-fixed.zip

echo "✅ Layer update complete!"
echo "🧪 Test your function now - the fpdf error should be resolved."
