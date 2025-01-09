# QOI Implementation in Jai

This repository contains an implementation of the [QOI (Quite OK Image)](https://github.com/phoboslab/qoi/) format in the [Jai programming language](https://en.wikipedia.org/?title=JAI_(programming_language)).

> QOI is fast. It losslessly compresses images to a similar size of PNG, while offering 20x-50x faster encoding and 3x-4x faster decoding.

## Features

- Compliant with the [latest](https://qoiformat.org/qoi-specification.pdf) QOI format specification.
- Clean and minimal codebase for easy understanding and modification.

## Usage

```odin
QOI_STDIO :: true; // qoi_write() and qoi_read()
#load "qoi.jai";
```

#### Encoding
```odin
Qoi_Desc desc = .{
  width      = ...,
  height     = ...,
  channels   = ...,
  colorspace = ...,
};

bytes, ok := qoi_encode(pixels, desc);
bytes := qoi_encode(pixels, desc); // checking the result is optional
```
or
```odin
bytes, ok := qoi_encode(pixels, width, height, channels, colorspace);
bytes, ok := qoi_encode(pixels, width, height); // channel and colorspace are optional
```

#### Decoding
```odin
pixels, desc, ok := qoi_decode(bytes);
pixels, desc, ok := qoi_decode(bytes, 4); // preferred channels, 3: RGB, 4: RGBA
```

#### Reading from file
```odin
Qoi_Desc desc = .{
  width      = ...,
  height     = ...,
  channels   = ...,
  colorspace = ...,
};

len := qoi_write(filename, pixels, desc);
qoi_write(filename, pixels, desc); // getting the bytes count writed is optional
```
or
```odin
qoi_write(filename, pixels, width, height, channels, colorspace);
qoi_write(filename, pixels, width, height); // channel and colorspace are optional
```

#### Writing to file
```odin
pixels, desc, ok := qoi_read(filename);
pixels, desc, ok := qoi_read(filename, 4); // preferred channels, 3: RGB, 4: RGBA
```

### License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

