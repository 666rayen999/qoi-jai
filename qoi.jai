#import "Basic";

Qoi_Format :: enum u8 {
    SRGB   :: 0;
    LINEAR :: 1;
}

Qoi_Desc :: struct {
    width      : u32;
    height     : u32;
    channels   : u8;
    colorspace : Qoi_Format;
}

qoi_encode :: inline (pixels: []u8, width: u32, height: u32, channels : u8 = 0, colorspace : Qoi_Format = .SRGB) -> []u8 #must, bool {
    bytes, ok := qoi_encode(pixels, .{
        width      = width,
        height     = height,
        channels   = channels,
        colorspace = colorspace,
    });
    return bytes, ok;
}

qoi_encode :: (pixels: []u8, desc: Qoi_Desc) -> []u8 #must, bool {
    Qoi_Pixel :: union {
        struct { r, g, b, a: u8; };
        v: u32;
    }

    QOI_MAGIC : u32 : #run -> u32 {
        q : u32 = #char "q";
        o : u32 = #char "o";
        i : u32 = #char "i";
        f : u32 = #char "f";
        return (q << 24) | (o << 16) | (i << 8) | f;
    };

    QOI_HEADER_SIZE :: 14;
    qoi_padding : [8]u8 : .[0,0,0,0,0,0,0,1];
    QOI_PIXELS_MAX : u32 : 400000000;

    QOI_OP_INDEX : u8 : 0x00;
    QOI_OP_DIFF  : u8 : 0x40;
    QOI_OP_LUMA  : u8 : 0x80;
    QOI_OP_RUN   : u8 : 0xc0;
    QOI_OP_RGB   : u8 : 0xfe;
    QOI_OP_RGBA  : u8 : 0xff;
    QOI_MASK_2   : u8 : 0xc0;

    color_hash :: inline (using color: Qoi_Pixel) -> u8 { return (r*3 + g*5 + b*7 + a*11) & 63; }
    qoi_write_8 :: inline (x: u8) #expand { `bytes[`p] = x; `p += 1; }
    qoi_write_32 :: inline (v: u32) #expand {
        `bytes[`p] = cast,no_check(u8) (v >> 24);
        `bytes[`p+1] = cast,no_check(u8) (v >> 16);
        `bytes[`p+2] = cast,no_check(u8) (v >> 8);
        `bytes[`p+3] = cast,no_check(u8) v;
        `p += 4;
    }

    index : [64]Qoi_Pixel;

    if  pixels.count == 0   || pixels.data == null ||
        desc.width == 0     || desc.height == 0    ||
        desc.channels < 3   || desc.channels > 4   ||
        desc.colorspace > 1 ||
        desc.height >= QOI_PIXELS_MAX / desc.width
    return .[], false;

    max_size : u32 = desc.width * desc.height * (desc.channels + 1) + QOI_HEADER_SIZE + qoi_padding.count;

    p : u32 = 0;

    bytes : []u8 = .{ max_size, alloc(max_size) };
    if bytes.data == null return .[], false;

    qoi_write_32(QOI_MAGIC);
    qoi_write_32(desc.width);
    qoi_write_32(desc.height);
    qoi_write_8(desc.channels);
    qoi_write_8(cast(u8) desc.colorspace);

    run       : u8 = 0;
    px        : Qoi_Pixel;
    px_prev   : Qoi_Pixel;
    px.a      = 0xFF;
    px_prev.a = 0xFF;

    px_len   : u32 = desc.width * desc.height * desc.channels;
    channels :  u8 = desc.channels;
    px_end   : u32 = px_len - channels;

    px_pos : u32 = 0;
    while px_pos < px_len {
        px.r = pixels[px_pos];
        px.g = pixels[px_pos+1];
        px.b = pixels[px_pos+2];

        if channels == 4 px.a = pixels[px_pos+3];

        if px.v == px_prev.v {
            run += 1;
            if run == 62 || px_pos == px_end {
                qoi_write_8(QOI_OP_RUN | (run - 1));
                run = 0;
            }
        } else {
            if run > 0 {
                qoi_write_8(QOI_OP_RUN | (run - 1));
                run = 0;
            }

            index_pos : u8 = color_hash(px);

            if index[index_pos].v == px.v qoi_write_8(QOI_OP_INDEX | index_pos);
            else {
                index[index_pos] = px;

                if (px.a == px_prev.a) {
                    vr := px.r - px_prev.r;
                    vg := px.g - px_prev.g;
                    vb := px.b - px_prev.b;
                    vg_r := vr - vg;
                    vg_b := vb - vg;

                    if vr > -3 && vr < 2 && vg > -3 && vg < 2 && vb > -3 && vb < 2
                        qoi_write_8(QOI_OP_DIFF | cast,no_check(u8) (((vr + 2) << 4) | ((vg + 2) << 2) | (vb + 2)));
                    else if vg_r > -9 && vg_r < 8 && vg > -33 && vg < 32 && vg_b > -9 && vg_b < 8 {
                        qoi_write_8(QOI_OP_LUMA | cast,no_check(u8) (vg + 32));
                        qoi_write_8(cast,no_check(u8) ((vg_r + 8) << 4 | (vg_b + 8)));
                    } else {
                        qoi_write_8(QOI_OP_RGB);
                        qoi_write_8(px.r);
                        qoi_write_8(px.g);
                        qoi_write_8(px.b);
                    }
                } else {
                    qoi_write_8(QOI_OP_RGBA);
                    qoi_write_8(px.r);
                    qoi_write_8(px.g);
                    qoi_write_8(px.b);
                    qoi_write_8(px.a);
                }
            }
        }

        px_prev = px;
        px_pos += channels;
    }

    for 0..qoi_padding.count - 1 qoi_write_8(qoi_padding[it]);

    bytes.count = p;

    return bytes, true;
}


qoi_decode :: (bytes: []u8, channels : u8 = 0) -> []u8 #must, Qoi_Desc #must, bool {
    Qoi_Pixel :: union {
        struct { r, g, b, a: u8; };
        v: u32;
    }

    QOI_MAGIC : u32 : #run -> u32 {
        q : u32 = #char "q";
        o : u32 = #char "o";
        i : u32 = #char "i";
        f : u32 = #char "f";
        return (q << 24) | (o << 16) | (i << 8) | f;
    };

    QOI_HEADER_SIZE :: 14;
    qoi_padding : [8]u8 : .[0,0,0,0,0,0,0,1];
    QOI_PIXELS_MAX : u32 : 400000000;

    QOI_OP_INDEX : u8 : 0x00;
    QOI_OP_DIFF  : u8 : 0x40;
    QOI_OP_LUMA  : u8 : 0x80;
    QOI_OP_RUN   : u8 : 0xc0;
    QOI_OP_RGB   : u8 : 0xfe;
    QOI_OP_RGBA  : u8 : 0xff;
    QOI_MASK_2   : u8 : 0xc0;

    color_hash :: inline (using color: Qoi_Pixel) -> u8 { return (r*3 + g*5 + b*7 + a*11) & 63; }
    qoi_read_8 :: inline () -> u8 #expand { x : u8 = `bytes[`p]; `p += 1; return x; }
    qoi_read_32 :: inline () -> u32 #expand {
        a : u32 = `bytes[`p];
        b : u32 = `bytes[`p+1];
        c : u32 = `bytes[`p+2];
        d : u32 = `bytes[`p+3];
        `p += 4;
        res: u32 = (a << 24) | (b << 16) | (c << 8) | d;
        return res;
    }

    desc : Qoi_Desc = ---;

    if  bytes.data == null ||
        (channels != 0 && channels != 3 && channels != 4) ||
        bytes.count < QOI_HEADER_SIZE + qoi_padding.count
    return .[], desc, false;

    p : u32 = 0;

    magic : u32 = qoi_read_32();
    if magic != QOI_MAGIC return .[], desc, false;

    desc.width      = qoi_read_32();
    desc.height     = qoi_read_32();
    desc.channels   = qoi_read_8();
    colorspace : u8 = qoi_read_8();

    if  desc.width == 0   ||
        desc.height == 0  ||
        desc.channels < 3 ||
        desc.channels > 4 ||
        colorspace > 1    ||
        desc.height >= QOI_PIXELS_MAX / desc.width
    return .[], desc, false;

    desc.colorspace = xx colorspace;

    if channels == 0 channels = desc.channels;

    px_len : u32 = desc.width * desc.height * channels;

    pixels : []u8 = .{ px_len, alloc(px_len) };
    if pixels.data == null return .[], desc, false;

    index : [64]Qoi_Pixel;
    px    : Qoi_Pixel;
    px.a  = 0xFF;

    run : u8 = 0;
    chunks_len : u32 = cast(u32) (bytes.count - qoi_padding.count);

    px_pos : u32 = 0;
    while px_pos < px_len {
        if run > 0 run -= 1;
        else if p < chunks_len {
            b1 : u8 = qoi_read_8();
            if b1 == QOI_OP_RGB {
                px.r = qoi_read_8();
                px.g = qoi_read_8();
                px.b = qoi_read_8();
            } else if b1 == QOI_OP_RGBA {
                px.r = qoi_read_8();
                px.g = qoi_read_8();
                px.b = qoi_read_8();
                px.a = qoi_read_8();
            } else if (b1 & QOI_MASK_2) == QOI_OP_INDEX px = index[b1];
            else if (b1 & QOI_MASK_2) == QOI_OP_DIFF {
                px.r += ((b1 >> 4) & 0x03) - 2;
                px.g += ((b1 >> 2) & 0x03) - 2;
                px.b += ( b1       & 0x03) - 2;
            } else if (b1 & QOI_MASK_2) == QOI_OP_LUMA {
                b2 : s8 = cast,no_check(s8) qoi_read_8();
                vg : s8 = (cast,no_check(s8) (b1 & 0x3f)) - 32;
                px.r += cast,no_check(u8) (vg - 8 + ((b2 >> 4) & 0x0f));
                px.b += cast,no_check(u8) (vg - 8 + (b2        & 0x0f));
                px.g += cast,no_check(u8) vg;
            } else if (b1 & QOI_MASK_2) == QOI_OP_RUN run = b1 & 0x3f;

            index[color_hash(px)] = px;
        }

        pixels[px_pos]   = px.r;
        pixels[px_pos+1] = px.g;
        pixels[px_pos+2] = px.b;

        if channels == 4 pixels[px_pos + 3] = px.a;

        px_pos += channels;
    }

    return pixels, desc, true;
}

#if #exists(QOI_STDIO) {
#if QOI_STDIO {

#import "File";

qoi_write :: inline (filename: string, pixels: []u8, width: u32, height: u32, channels : u8 = 0, colorspace : Qoi_Format = .SRGB) -> u32 {
    bytes, ok := qoi_encode(pixels, width, height, channels, colorspace);
    if !ok || !write_entire_file(filename, bytes.data, bytes.count) return 0;
    else return xx bytes.count;
}

qoi_write :: inline (filename: string, pixels: []u8, desc: Qoi_Desc) -> u32 {
    bytes, ok := qoi_encode(pixels, desc);
    if !ok || !write_entire_file(filename, bytes.data, bytes.count) return 0;
    else return xx bytes.count;
}

qoi_read :: inline (filename: string, channels : u8 = 0) -> []u8 #must, Qoi_Desc #must, bool {
    file, k := read_entire_file(filename);
    d : Qoi_Desc = ---;
    if !k return .[], d, false;

    f: []u8 = .{ file.count, file.data };
    pixels, desc, ok := qoi_decode(f, channels);
    return pixels, desc, ok;
}

}} // QOI_STDIO
