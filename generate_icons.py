#!/usr/bin/env python3
"""
Generate placeholder app icons for TradingGuru
Creates icons with an upward trending chart design
"""

from PIL import Image, ImageDraw
import os
import math

# Icon directory
ICON_DIR = "/Users/kamauagg/workspace/TradingGuru/TradingGuru/Assets.xcassets/AppIcon.appiconset"

# Colors
DARK_NAVY = (26, 31, 60)       # #1A1F3C - Background
TRADING_GREEN = (52, 199, 89)   # #34C759 - Bullish
GOLD = (255, 215, 0)            # #FFD700 - Accent
WHITE = (255, 255, 255)
DARK_BG = (15, 18, 35)          # Even darker for dark mode
GRAY = (128, 128, 128)          # For tinted version

def draw_rounded_rect(draw, coords, radius, fill):
    """Draw a rounded rectangle"""
    x1, y1, x2, y2 = coords
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)
    draw.ellipse([x1, y1, x1 + 2*radius, y1 + 2*radius], fill=fill)
    draw.ellipse([x2 - 2*radius, y1, x2, y1 + 2*radius], fill=fill)
    draw.ellipse([x1, y2 - 2*radius, x1 + 2*radius, y2], fill=fill)
    draw.ellipse([x2 - 2*radius, y2 - 2*radius, x2, y2], fill=fill)

def create_icon(size, bg_color, chart_color, accent_color, filename):
    """Create a single app icon"""
    img = Image.new('RGB', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Calculate dimensions relative to icon size
    margin = int(size * 0.15)
    chart_margin = int(size * 0.2)
    
    # Draw a subtle gradient-like background (concentric rounded rects)
    for i in range(5):
        alpha = 255 - (i * 10)
        shade = tuple(min(c + i * 3, 255) for c in bg_color)
        offset = i * int(size * 0.02)
        draw_rounded_rect(draw, 
                         [offset, offset, size - offset, size - offset],
                         int(size * 0.18) - offset,
                         shade)
    
    # Draw chart area background (subtle darker area)
    chart_bg = tuple(max(c - 15, 0) for c in bg_color)
    chart_x1 = chart_margin
    chart_y1 = int(size * 0.25)
    chart_x2 = size - chart_margin
    chart_y2 = size - chart_margin
    draw_rounded_rect(draw, [chart_x1, chart_y1, chart_x2, chart_y2], 
                     int(size * 0.05), chart_bg)
    
    # Draw upward trending line chart
    line_width = max(int(size * 0.025), 3)
    
    # Chart points (relative positions) - upward trend
    points_rel = [
        (0.25, 0.75),   # Start low left
        (0.35, 0.65),   # Small dip
        (0.45, 0.55),   # Rise
        (0.55, 0.60),   # Small pullback
        (0.65, 0.45),   # Strong rise
        (0.75, 0.35),   # Peak area
    ]
    
    # Convert to absolute coordinates
    points = [(int(x * size), int(y * size)) for x, y in points_rel]
    
    # Draw the chart line with glow effect
    # Glow
    for glow_offset in range(4, 0, -1):
        glow_alpha = 60 - glow_offset * 15
        glow_color = tuple(list(chart_color) + [glow_alpha]) if len(chart_color) == 3 else chart_color
        glow_width = line_width + glow_offset * 2
        for i in range(len(points) - 1):
            draw.line([points[i], points[i+1]], fill=chart_color, width=glow_width)
    
    # Main line
    for i in range(len(points) - 1):
        draw.line([points[i], points[i+1]], fill=chart_color, width=line_width)
    
    # Draw dots at data points
    dot_radius = int(size * 0.02)
    for point in points:
        draw.ellipse([point[0] - dot_radius, point[1] - dot_radius,
                     point[0] + dot_radius, point[1] + dot_radius], 
                    fill=chart_color)
    
    # Draw upward arrow at the end (signal indicator)
    arrow_x = points[-1][0] + int(size * 0.05)
    arrow_y = points[-1][1] - int(size * 0.05)
    arrow_size = int(size * 0.08)
    
    # Arrow pointing up
    arrow_points = [
        (arrow_x, arrow_y - arrow_size),  # Top
        (arrow_x - arrow_size//2, arrow_y),  # Bottom left
        (arrow_x + arrow_size//2, arrow_y),  # Bottom right
    ]
    draw.polygon(arrow_points, fill=accent_color)
    
    # Draw "TG" text or stylized element at top
    text_size = int(size * 0.12)
    text_x = int(size * 0.15)
    text_y = int(size * 0.12)
    
    # Draw a simple "G" with chart element (stylized logo mark)
    # Small candlestick bars at top left corner
    candle_width = int(size * 0.025)
    candle_spacing = int(size * 0.04)
    candle_heights = [0.08, 0.12, 0.10, 0.14]  # Relative heights
    
    for i, height in enumerate(candle_heights):
        cx = text_x + i * candle_spacing
        cy = text_y + int(size * 0.15)
        ch = int(size * height)
        
        # Wick
        draw.line([(cx + candle_width//2, cy - ch//4), 
                   (cx + candle_width//2, cy + ch + ch//4)],
                  fill=accent_color, width=1)
        
        # Body
        if i % 2 == 0:  # Green candle
            draw.rectangle([cx, cy, cx + candle_width, cy + ch], fill=chart_color)
        else:  # Red/accent candle
            draw.rectangle([cx, cy, cx + candle_width, cy + ch], fill=accent_color)
    
    # Save the icon
    filepath = os.path.join(ICON_DIR, filename)
    img.save(filepath, 'PNG')
    print(f"Created: {filename}")
    return filepath

def main():
    """Generate all required app icons"""
    
    os.makedirs(ICON_DIR, exist_ok=True)
    
    # Create main icon (light mode)
    create_icon(1024, DARK_NAVY, TRADING_GREEN, GOLD, "AppIcon.png")
    
    # Create dark mode icon (even darker background, brighter elements)
    create_icon(1024, DARK_BG, TRADING_GREEN, GOLD, "AppIcon-Dark.png")
    
    # Create tinted icon (grayscale version)
    create_icon(1024, (40, 40, 45), (180, 180, 180), (220, 220, 220), "AppIcon-Tinted.png")
    
    # Update Contents.json with the new filenames
    contents_json = '''{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-Tinted.png",
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
'''
    
    contents_path = os.path.join(ICON_DIR, "Contents.json")
    with open(contents_path, 'w') as f:
        f.write(contents_json)
    print(f"Updated: Contents.json")
    
    print("\n✅ App icons generated successfully!")
    print(f"Location: {ICON_DIR}")
    print("\nNote: These are placeholder icons. For App Store submission,")
    print("consider hiring a designer for professional icons.")

if __name__ == "__main__":
    main()
