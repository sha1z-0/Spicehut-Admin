#!/usr/bin/env python3
"""
Script to fix the app icon aspect ratio
Converts any rectangular image to a square by adding padding
"""

from PIL import Image  # type: ignore
import os

def fix_icon_aspect_ratio(input_path, output_path, bg_color=(255, 255, 255)):
    """
    Convert an image to a square by adding padding while maintaining aspect ratio
    
    Args:
        input_path: Path to the input image
        output_path: Path to save the squared image
        bg_color: RGB tuple for background color (default: white)
    """
    # Open the image
    img = Image.open(input_path)
    
    # Get original dimensions
    width, height = img.size
    print(f"Original image size: {width}x{height}")
    
    # Determine the size of the square (use the larger dimension)
    square_size = max(width, height)
    print(f"Square size will be: {square_size}x{square_size}")
    
    # Create a new square image with white background
    square_img = Image.new('RGBA', (square_size, square_size), bg_color + (255,))
    
    # Calculate position to center the original image
    x_offset = (square_size - width) // 2
    y_offset = (square_size - height) // 2
    
    # Paste the original image onto the square canvas
    if img.mode == 'RGBA':
        square_img.paste(img, (x_offset, y_offset), img)
    else:
        square_img.paste(img, (x_offset, y_offset))
    
    # Save the result
    square_img.convert('RGB').save(output_path, 'PNG')
    print(f"Fixed icon saved to: {output_path}")
    print(f"New size: {square_size}x{square_size}")

if __name__ == '__main__':
    # Configuration
    input_file = 'assets/logo/spicehut_logo.png'
    output_file = 'assets/logo/spicehut_logo.png'
    
    # Orange background color (matching your brand color #FF7A00)
    brand_orange = (255, 122, 0)
    
    if os.path.exists(input_file):
        print("Converting logo to square aspect ratio...")
        # Backup original
        backup_file = 'assets/logo/spicehut_logo_backup.png'
        if not os.path.exists(backup_file):
            import shutil
            shutil.copy(input_file, backup_file)
            print(f"Backed up original to: {backup_file}")
        
        # Fix aspect ratio with white background
        fix_icon_aspect_ratio(input_file, output_file, bg_color=(255, 255, 255))
        print("\n✓ Icon aspect ratio fix complete!")
        print("You can now rebuild the app with: flutter build apk --release")
    else:
        print(f"Error: {input_file} not found")
