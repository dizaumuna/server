from imgextractor import ULTRAMAN
import sys
import os

def main():
    if len(sys.argv) < 3:
        print("usage: python extract.py yourimage.img outputfolder")
        return

    img = sys.argv[1]
    out = sys.argv[2]

    if not os.path.exists(img):
        print("no image found >_<")
        return

    if not os.path.exists(out):
        os.makedirs(out)

    ext = ULTRAMAN()
    ext.MONSTER(img, out)

    print("finished")

if __name__ == "__main__":
    main()