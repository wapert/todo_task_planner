# Daily quote sources

The Western quotation library is generated from John Bartlett's *Familiar
Quotations*, ninth edition (1905), Project Gutenberg ebook 27889. Project
Gutenberg identifies this edition as public domain in the United States.

Source: https://www.gutenberg.org/ebooks/27889

The generated app data contains short quotation text and author attribution.
It does not include Project Gutenberg's ebook text, headers, or license text.
To regenerate the collection, download the plain-text edition and run:

```sh
dart run tool/build_bartlett_quotes.dart pg27889.txt \
  lib/data/western_wisdom_quotes.dart
```

The Traditional Chinese library is generated from the public-domain Project
Gutenberg editions of 《論語》(23839), 《孟子》(24178), 《道德經》(7337),
《墨子》(24240), and 《淮南子》(24059).

```sh
dart run tool/build_chinese_quotes.dart chinese_texts \
  lib/data/chinese_wisdom_quotes.dart
```
