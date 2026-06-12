from PIL import Image

def crop_icon():
    img_path = r"C:\Users\MidNight Hawk\.gemini\antigravity-ide\brain\607a50d0-3fea-405d-8ba3-18d218654f87\media__1781206959712.jpg"
    img = Image.open(img_path)
    width, height = img.size
    print(f"Original size: {width}x{height}")

    # The icon is a square in the center.
    # We'll crop a square from the center.
    # Let's crop a box that is 68% of the width, centered.
    size = int(width * 0.68)
    left = (width - size) // 2
    top = (height - size) // 2 + 10 # slightly offset top depending on status bar
    
    box = (left, top, left + size, top + size)
    cropped = img.crop(box)
    
    # Save to assets/icon.png
    out_path = "assets/icon.png"
    cropped.save(out_path)
    print(f"Saved cropped to {out_path} with size {size}x{size}")

if __name__ == "__main__":
    crop_icon()
