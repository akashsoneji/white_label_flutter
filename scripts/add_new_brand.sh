#!/bin/bash
#
# scripts/add_new_brand.sh
#
# Scaffolds a new brand (parent or child) with all required directories and assets.
# After running, add the brand to assets/config/brands/brands.yaml and regenerate.
#
# Usage:
#   ./scripts/add_new_brand.sh newparent --type parent
#   ./scripts/add_new_brand.sh newchild --type child --parent vantage

NAME=""
TYPE=""
PARENT=""

while [ $# -gt 0 ]; do
    case $1 in
        --type) TYPE="$2"; shift 2 ;;
        --parent) PARENT="$2"; shift 2 ;;
        -*) echo "Unknown option: $1"; exit 1 ;;
        *) NAME="$1"; shift ;;
    esac
done

if [ -z "$NAME" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 {brand_name} --type parent|child [--parent parent_brand]"
    echo ""
    echo "Examples:"
    echo "  ./scripts/add_new_brand.sh stellar --type parent"
    echo "  ./scripts/add_new_brand.sh stellar_child --type child --parent stellar"
    exit 1
fi

echo "Creating brand: $NAME (type: $TYPE)"

# Create brand assets directory
mkdir -p "assets/brands/$NAME"

# Create placeholder SVG files
cat > "assets/brands/$NAME/logo.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"/>
SVG
cp "assets/brands/$NAME/logo.svg" "assets/brands/$NAME/splash_logo.svg"

# Copy a placeholder icon (use Vantage's as default — replace with actual icon)
if [ -f "assets/brands/vantage/icon.png" ]; then
    cp "assets/brands/vantage/icon.png" "assets/brands/$NAME/icon.png"
fi

if [ "$TYPE" == "parent" ]; then
    echo "Creating parent brand structure..."

    # Create screen directories for all features (parent brands have their own design)
    for feature in auth home finance pmam copy_trading kyc trade_win ib; do
        mkdir -p "lib/screens/$feature/presentation/brands/$NAME/pages"
        mkdir -p "lib/screens/$feature/presentation/brands/$NAME/widgets"
        echo "  Created: lib/screens/$feature/presentation/brands/$NAME/"
    done

    # Create lib/clients/{brand}/ directory
    mkdir -p "lib/clients/$NAME/assets"

    echo ""
    echo "NEXT STEPS:"
    echo "  1. Replace placeholder assets in assets/brands/$NAME/ with actual files"
    echo "     - icon.png (1024x1024)"
    echo "     - logo.svg"
    echo "     - splash_logo.svg"
    echo "  2. Create screen files in lib/screens/*/brands/$NAME/ for your design"
    echo "  3. Add entry to assets/config/brands/brands.yaml"
    echo "  4. Run: dart run scripts/generate_brand_config.dart"
    echo "  5. Build: ./build.sh $NAME apk release"

elif [ "$TYPE" == "child" ]; then
    if [ -z "$PARENT" ]; then
        echo "ERROR: Child brand requires --parent flag"
        exit 1
    fi

    echo "Creating child brand (inherits from: $PARENT)..."
    echo "  NOTE: No screen directories created — child uses parent's screens"

    # Create lib/clients/{brand}/ directory
    mkdir -p "lib/clients/$NAME/assets"

    # Copy parent icon as placeholder
    if [ -f "assets/brands/$PARENT/icon.png" ]; then
        cp "assets/brands/$PARENT/icon.png" "assets/brands/$NAME/icon.png"
        echo "  Copied icon from: assets/brands/$PARENT/icon.png"
    fi

    echo ""
    echo "NEXT STEPS:"
    echo "  1. Replace placeholder assets in assets/brands/$NAME/ with actual files"
    echo "  2. Add entry to assets/config/brands/brands.yaml:"
    echo "     - name: $NAME"
    echo "       type: child"
    echo "       inheritsFrom: $PARENT"
    echo "       label: $NAME"
    echo "       colors: { primary: \"#XXXXXX\", ... }"
    echo "       urls: { api: \"...\", ... }"
    echo "  3. Run: dart run scripts/generate_brand_config.dart"
    echo "  4. Build: ./build.sh $NAME apk release"
    echo "  5. Later: to give this brand its own design, create files in lib/screens/*/brands/$NAME/"
fi

echo ""
echo "Brand '$NAME' scaffold created successfully."