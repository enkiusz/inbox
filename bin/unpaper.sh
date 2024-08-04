#!/usr/bin/env bash

export LC_ALL=C

set -o errexit -o pipefail
set -x

[ -z "$INBOX_CONF" ] && INBOX_CONF="/etc/default/inbox.conf"
eval "$(ini2bash "$INBOX_CONF")"

set -o nounset

die() {
    echo $* 1>&2
    exit 1
}

usage() {
    die "Usage: $0 [-v] [-p] [-k] [-r] [-o <output file>] [image]"
}


tmpfiles=()  # Track list of tmpfiles

tmpdir() {
    mktemp -d -t unpaper-XXXXXXX
}

tmpfile() {
    mktemp -t unpaper-XXXXXXX.ppm
}

cleanup_tmpfiles() {
    [ -z "${keep_tmpfiles:-}" ] && rm -r "${tmpfiles[@]}"
}

trap cleanup_tmpfiles SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

masksize() {
    tr "," " " | (
        read x1 y1 x2 y2
        echo x1=$x1 y1=$y1 x2=$x2 y2=$y2 1>&2
        echo $((x2-x1)) $((y2-y1))
    )
}

fix_orientation() {
    file="$1"
    echo "$file: detecting orientation" 1>&2
    ~/repos/github.com/enkiusz/inbox/bin/detect-orientation "$file" | (
        read angle confidence filename
        echo "$file: detected orientation angle=$angle confidence=$confidence filename='$filename'" 1>&2
        if [ "$angle" != "NaN" -a "$angle" != "NaN" ]; then
            t=$(mktemp unpaper-XXXXXXX.png)
            convert -rotate -$angle "$file" "$t"
            mv "$t" "$file"
        fi
    )
}

preserve_attributes=""
verbose=""
keep_tmpfiles=""
rotate=""

while getopts ":vpkro:" o; do
    case "$o" in
        v)
            verbose=1
            ;;
	      p)
            preserve_attributes=1
            ;;
        k)
            keep_tmpfiles=1
            ;;
        o)
            OUTIMG=$OPTARG
            ;;
        r)
            rotate=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

IMG="$1"; shift

if ! [ -s "$IMG" ]; then
    echo "$IMG: File is a placeholder (size is 0 bytes), skipping" 1>&2
    exit 0
fi

if [ -n "$preserve_attributes" ]; then
    exif_dir=$(tmpdir)
    tmpfiles+=($exif_dir)

    echo "$IMG: EXIF and timestmaps will be preserved in '$exif_dir'" 1>&2
    exiv2 -l $exif_dir -e a extract "$IMG"
    touch --reference "$IMG" $exif_dir/$(basename "$IMG")
fi

if [ -z "${OUTIMG:-}" ]; then
    in_place=true
    echo "$IMG: Processing image in-place" 1>&2
    OUTIMG="$IMG"
else
    echo "$IMG: Output image will be '$OUTIMG'" 1>&2
fi

tmpfile=$(tmpfile)
tmpfiles+=($tmpfile)
echo "$IMG: Deskewing and adding border < '$IMG' > '$tmpfile'" 1>&2
convert "$IMG" -bordercolor black -border 100x100 -negate -deskew ${workflow_deskew[deskew_percentage]}% -negate $tmpfile

# Calculate centroid
echo "$IMG: Finding image centroid < '$tmpfile'" 1>&2
image-centroid $tmpfile | while read x y filename; do
    trap cleanup_tmpfiles SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM

    echo "$IMG: centroid x='$x' y='$y'" 1>&2

    tmpfile2=$(tmpfile); tmpfiles+=($tmpfile2)
    echo "$IMG: Calculating negative to help with unpaper processing < '$tmpfile' > '$tmpfile2'" 1>&2
    convert $tmpfile -negate $tmpfile2

    echo "$IMG: Calculating document mask < '$tmpfile2'" 1>&2
    # Use mask-scan-size 5,5 to reliably detect sharp edges of paper sheets near the borders
    MASK_OUT=$(unpaper -T -vvv --overwrite --layout none \
            --no-blackfilter --no-noisefilter --no-blurfilter --no-grayfilter --no-deskew \
            --mask-scan-point "$x,$y" \
            --mask-scan-size ${workflow_unpaper[mask_scan_size]} \
            --mask-scan-direction h,v $tmpfile2 /dev/null)
    MASK=$(echo -n "$MASK_OUT" | grep "auto-masking ($x,$y): " | tail -n 1 | awk -F": " '{print $2;}')
    [ -n "$verbose" ] && echo "$IMG: mask detection out: $MASK_OUT" 1>&2
    echo "$IMG: detected mask '$MASK'" 1>&2
    if [ "$MASK" != "NO MASK FOUND" ]; then

        tmpfile3=$(tmpfile); tmpfiles+=($tmpfile3)
        echo "$IMG: Extracting mask region from original image < '$tmpfile2' > '$tmpfile3'" 1>&2
        unpaper ${verbose:+-vvv} --layout single --overwrite \
                --no-blackfilter --no-noisefilter --no-blurfilter --no-grayfilter --no-deskew \
                --no-mask-scan --mask "$MASK" \
                $tmpfile2 $tmpfile3

        echo $MASK | masksize | (
            read dx dy
            echo "$IMG: Recentering and cropping masked region < '$tmpfile3' > '$OUTIMG'" 1>&2
            echo convert -debug all $tmpfile3 -gravity Center -crop $((dx))x$((dy))+0+0\! -negate "$OUTIMG"
            convert -debug all $tmpfile3 -gravity Center -crop $((dx))x$((dy))+0+0\! -negate "$OUTIMG"
            echo "Convertion completed rval=$?"
            [ "z$rotate" = "z1" ] && fix_orientation "$OUTIMG"
            echo "z"
        )
        echo "aaa"
    else
        echo "$IMG: No mask could be detected, skipping" 1>&2
        if [ -z "$in_place" ]; then
           cp "$IMG" "$OUTIMG"
           [ "z$rotate" = "z1" ] && fix_orientation "$OUTIMG"
        fi
    fi

    echo "Checking if preserve attributes is set"
    if [ -n "$preserve_attributes" ]; then
        echo "Preserving attributes"
        # Copy the EXIF information and timestamps
        exiv2 -l $exif_dir -i a insert "$OUTIMG"
        touch --reference $exif_dir/$(basename "$IMG") "$OUTIMG"
    fi

    echo 'cleanup:' "${tmpfiles[@]}" 1>&2
    cleanup_tmpfiles
done

exit 0
