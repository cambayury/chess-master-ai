import cairosvg

svg_code = open('icon.svg', 'r').read()

sizes = [48, 72, 96, 144, 192, 512, 1024]
for size in sizes:
    cairosvg.svg2png(
        bytestring=svg_code.encode(),
        write_to=f"icon_{size}.png",
        output_width=size,
        output_height=size
    )
    print(f"Generated icon_{size}.png")

print("Done!")