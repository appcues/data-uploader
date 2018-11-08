# Appcues Data Uploader

A command-line tool for uploading CSVs of user profile data to the
Appcues API (https://api.appcues.com/).

## Requirements

Appcues Data Uploader is written in Ruby, with zero dependencies.
Requires Ruby 2.0 or above (standard on OS X and most Unix).

This software is designed for use at the command line, i.e.,
from Terminal.app (OS X), Gnome-terminal or Xterm (Unix), or similar.

## How It Works

`appcues-data-uploader` takes CSV files containing user IDs and
profile attributes to update, and performs these updates by making
HTTP requests to the Appcues API.  Failed updates are retried until
they succeed.

## CSV Input Format

CSVs passed as input to `appcues-data-uploader` must start with
a row of header names.  One of these header names must be `user ID`
or something like it (e.g., `userID`, `user_id`, etc).  Other header
names will be used verbatim as profile attribute names.

Boolean (`true`/`false`), `null`, and numeric attribute values will
be converted to the proper data type.  Other values are treated as
strings.

## Installation and Usage

Install with RubyGems:

```bash
sudo gem install appcues_data_uploader`

appcues-data-uploader --account_id 1337 file.csv
```

Or install locally with Git:

```bash
git clone https://github.com/appcues/data-uploader.git appcues-data-uploader

cd appcues-code-uploader
bin/appcues-data-uploader --account_id 1337 file.csv
```

Or download it manually, if Git is not available:

```bash
curl https://codeload.github.com/appcues/data-uploader/zip/master > appcues-code-uploader.zip
unzip appcues-code-uploader.zip
rm appcues-code-uploader.zip
mv appcues-code-uploader-master appcues-code-uploader

cd appcues-code-uploader
bin/appcues-data-uploader --account_id 1337 file.csv
```

Run `appcues-data-uploader -h` to see all usage options.

## Testing

Run tests with `rake test`.

## Authorship and License

Copyright 2018 Appcues, Inc.

This software is released under the MIT License, whose text is
available in `LICENSE.txt`.
