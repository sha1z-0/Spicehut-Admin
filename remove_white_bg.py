#!/usr/bin/env python3
"""
Remove white background from logo and make it transparent
"""
from PIL import Image

# Load the logo
logo_path = "assets/logo/spicehut_logo.png"
img = Image.open(logo_path)

# Convert to RGBA if not already
if img.mode != "RGBA":
    img = img.convert("RGBA")

# Create a new image with white background removed
width, height = img.size
new_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))

# Process each pixel
pixels = img.getdata()
new_pixels = []

for pixel in pixels:
    r, g, b = pixel[0], pixel[1], pixel[2]
    a = pixel[3] if len(pixel) > 3 else 255
    
    # Check if pixel is close to white (with tolerance of 30)
    if abs(r - 255) < 30 and abs(g - 255) < 30 and abs(b - 255) < 30:
        # Make it transparent
        new_pixels.append((r, g, b, 0))
    else:
        # Keep the pixel as is
        new_pixels.append((r, g, b, a))

# Put the new pixels into the image
new_img.putdata(new_pixels)

# Save the result
new_img.save(logo_path)
print(f"✅ Successfully removed white background from {logo_path}")
print(f"   Image is now transparent with dimensions: {new_img.size}")
