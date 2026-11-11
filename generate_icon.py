import os
from PIL import Image, ImageDraw

def create_app_icon():
    os.makedirs("assets/icon", exist_ok=True)
    size = (1024, 1024)
    image = Image.new("RGBA", size, (25, 118, 210, 255)) # #1976D2 Blue
    draw = ImageDraw.Draw(image)

    # Draw a clean rounded rectangle background or decorative elements
    # Let's draw a white outer ring or inner shield/bus shape for a clean logo

    # Outer white rounded card in center
    margin = 120
    box = [margin, margin, size[0] - margin, size[1] - margin]
    draw.rounded_rectangle(box, radius=180, fill=(255, 255, 255, 255))

    # Inside the white card, draw primary color bus / shield symbol
    # Bus body (blue)
    bus_left = 312
    bus_top = 340
    bus_right = 712
    bus_bottom = 720
    draw.rounded_rectangle([bus_left, bus_top, bus_right, bus_bottom], radius=60, fill=(25, 118, 210, 255))

    # Bus windshield / windows (white)
    window_top = 400
    window_bottom = 500
    draw.rounded_rectangle([362, window_top, 502, window_bottom], radius=20, fill=(255, 255, 255, 255))
    draw.rounded_rectangle([522, window_top, 662, window_bottom], radius=20, fill=(255, 255, 255, 255))

    # Bus headlights (yellow/amber or white)
    draw.ellipse([362, 590, 412, 640], fill=(255, 213, 79, 255))
    draw.ellipse([612, 590, 662, 640], fill=(255, 213, 79, 255))

    # Bus wheels (dark gray/black)
    draw.ellipse([372, 700, 452, 780], fill=(33, 33, 33, 255))
    draw.ellipse([572, 700, 652, 780], fill=(33, 33, 33, 255))

    image.save("assets/icon/app_icon.png")
    print("Successfully generated assets/icon/app_icon.png")

if __name__ == "__main__":
    create_app_icon()
