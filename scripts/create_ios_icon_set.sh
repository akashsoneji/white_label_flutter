#!/bin/bash

# Helper script to create iOS app icon set for a flavor
# Usage: ./create_ios_icon_set.sh <flavor_name> <icon_image_path>

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <flavor_name> <icon_image_path>"
    echo "Example: $0 tenax assets/tenaxCode/App_logo.png"
    exit 1
fi

FLAVOR=$1
ICON_IMAGE=$2
ICON_SET_NAME="${FLAVOR}_app_icon"
ICON_SET_PATH="ios/Runner/Assets.xcassets/${ICON_SET_NAME}.appiconset"

echo "🎨 Creating iOS icon set for $FLAVOR..."

# Create directory
mkdir -p "$ICON_SET_PATH"

# Copy the icon image
if [ ! -f "$ICON_IMAGE" ]; then
    echo "⚠️  Icon image not found: $ICON_IMAGE"
    echo "   Please provide a valid icon image path"
    exit 1
fi

# Copy icon to icon set directory
cp "$ICON_IMAGE" "$ICON_SET_PATH/icon.png"

# Create Contents.json based on AppIcon template
cat > "$ICON_SET_PATH/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ Created icon set: $ICON_SET_PATH"
echo "📝 Note: For production, you should add all required sizes:"
echo "   - 20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024"
echo "   You can use an online tool like https://www.appicon.co/ to generate all sizes"

