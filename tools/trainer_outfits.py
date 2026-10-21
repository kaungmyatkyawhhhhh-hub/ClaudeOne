# Trainer outfits (prompt 34): clean shirt / pants images for the trainers' muscle stage meshes.
# The stage meshes (ReplicatedStorage.BodyStages / LimbStages) map the classic clothing layout, but sideways their mapping
# jumps at every corner of the old template's faces (about 1 triangle in 5 squeezes a whole face of the image into a
# sliver): a classic Shirt drew the template's edges as white "tear" lines and its see-through gaps as skin. Up and down
# the mapping is close to level but not quite: where the muscles bulge (the lats, the shoulders) a row wanders, so even a
# hem or a cuff line came out jagged (tested 21 Oct). So each image is ONE solid color: nothing on it can tear or wander,
# at any body size (g000 to gmon). The details are real meshes instead (Shared/Gear: belts, wraps, knee sleeves, the
# whistle, Atlas's gold waistband).
# Usage: python tools/trainer_outfits.py <out dir>   -> <id>_shirt.png / <id>_pants.png (64 x 64, solid). Upload them and
# put the ids in Config/Trainers look.outfit (Shared/Outfit decides which pieces wear them: sleeves / legs).
import os
import sys
from PIL import Image

OUTFITS = {
    "RookieCoach": {"shirt": "#C8262C", "pants": "#1E1E22"},  # Coach Sam: red track jacket, black track pants
    "CardioCoach": {"shirt": "#2FAE55", "pants": "#2FAE55"},  # Coach Nia: green tank top and shorts
    "MoneyCoach": {"shirt": "#E8C21C", "pants": "#1E1E22"},   # Coach Lou: yellow polo (to the elbow), black pants
    "PumpCoach": {"shirt": "#7A3FC8", "pants": "#1E1E22"},    # Coach Rex: purple tank top, black shorts
    "AtlasCoach": {"shirt": "#16161A", "pants": "#16161A"},   # Duke Ironside: black sleeveless top, black shorts
    "BlazeCoach": {"shirt": "#141418", "pants": "#141418"},   # Volta: black sports top, black shorts
    "ShadeCoach": {"shirt": "#0E0E11", "pants": "#0E0E11"},   # The Shadow: black long sleeves, black shorts
    "AeonCoach": {"pants": "#F4F1EA"},                         # Atlas: marble, white shorts
}


# Shoes (coaches 1-4): the clients draw a rig's R15 feet with the avatar's composited texture (its Pants image over the
# skin), not the part's Color, so painting the feet does nothing. A shoes-only classic Pants image does it: the shoe color
# on the feet of the classic layout (the bottom of each leg's 4 sides and the sole squares), see-through everywhere else.
# The muscle pieces never wear it (Shared/Outfit: a trainer's outfit comes from his attributes, not his Pants).
SHOES = {"RookieCoach": "#F4F1EA", "CardioCoach": "#3A3A40", "MoneyCoach": "#16161A", "PumpCoach": "#2B2B30"}


def shoes_image(hexc):
    h = hexc.lstrip("#")
    color = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    img = Image.new("RGBA", (585, 559), (0, 0, 0, 0))
    for x0, sole in ((19, 217), (308, 308)):  # the right leg, the left leg
        img.paste(color, (x0, 462, x0 + 264, 484))   # the bottom of the 4 sides (the foot)
        img.paste(color, (sole, 485, sole + 64, 550))  # the sole square
    return img


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name in os.listdir(out):
        if name.endswith(".png"):
            os.remove(os.path.join(out, name))
    for tid, outfit in OUTFITS.items():
        for kind in ("shirt", "pants"):
            if kind in outfit:
                h = outfit[kind].lstrip("#")
                color = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
                Image.new("RGBA", (64, 64), color).save(os.path.join(out, f"{tid}_{kind}.png"))
        if tid in SHOES:
            shoes_image(SHOES[tid]).save(os.path.join(out, f"{tid}_shoes.png"))
        print("made", tid)


if __name__ == "__main__":
    main()
