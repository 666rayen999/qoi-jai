# QOI Implementation in Jai

This repository contains an implementation of the [QOI (Quite OK Image)](https://github.com/phoboslab/qoi/) image format in the [Jai programming language](https://en.wikipedia.org/?title=JAI_(programming_language)).

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
ok, bytes := qoi_encode(pixels, desc);
```

#### Decoding
```odin
ok, pixels, desc := qoi_decode(bytes);
ok, pixels, desc := qoi_decode(bytes, 4); // preferred channels, 3: RGB, 4: RGBA
```

#### Reading from file
```odin
qoi_write(filename, pixels, desc);
```

#### Writing to file
```odin
ok, pixels, desc := qoi_read(filename);
ok, pixels, desc := qoi_read(filename, 4); // preferred channels, 3: RGB, 4: RGBA
```

### License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

