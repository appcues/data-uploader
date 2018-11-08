#!/usr/bin/env ruby
#
# Appcues Data Uploader
#
# Throws CSV-formatted user profile data at the Appcues API.
# Run `appcues-data-uploader -h` for more information.

require 'net/http'
require 'csv'
require 'json'
require 'optparse'

class AppcuesDataUploader
  UserActivity = Struct.new(:account_id, :user_id, :profile_update, :events)
  UploadOpts = Struct.new(:account_id, :quiet, :csv_filenames)
  attr_reader :opts

  class << self
    def main(argv)
      options = UploadOpts.new

      option_parser = OptionParser.new do |opts|
        opts.banner =  <<-EOT
Usage: #{$0} [options] -a account_id [filename ...]

Uploads profile data from one or more CSVs to the Appcues API.

CSVs should start with a row of header names, including one named something
like "user ID". Other headers will be used verbatim as attribute names.

Attribute values can be boolean ('true' or 'false'), 'null', numeric, or
string-typed.

For example, the following CSV data:

    user_id,first_name,has_posse,height_in_inches
    u123,Pete,false,68.5
    u456,André,true,88

Will result in two profile updates:

    u123: {"first_name": "Pete", "has_posse": false, "height_in_inches": 68.5}
    u456: {"first_name": "André", "has_posse": true, "height_in_inches": 88}
        EOT

        opts.separator ""
        opts.separator "Options:"

        opts.on('-a', '--account-id ACCOUNT_ID', 'Set Appcues account ID') do |account_id|
          options.account_id = account_id
        end

        opts.on('-q', '--quiet', 'Do not emit debug output') do
          options.quiet = true
        end

        opts.on('-h', '--help', 'Print this message and exit') do
          puts opts
          exit
        end
      end

      csv_filenames = option_parser.parse(argv)
      csv_filenames = ["-"] if csv_filenames == []
      options.csv_filenames = csv_filenames

      if !options.account_id
        STDERR.puts "You must specify an account ID with the -a option."
        exit 1
      end

      new(options).perform_uploads()
    end
  end

  def initialize(init_opts)
    @opts = init_opts.is_a?(UploadOpts) ? init_opts : UploadOpts.new(
      init_opts[:account_id] || init_opts["account_id"],
      init_opts[:quiet] || init_opts["quiet"],
      init_opts[:csv_filenames] || init_opts["csv_filenames"]
    )

    if !opts.account_id
      raise ArgumentError, "account_id is required but missing"
    end

    if !opts.csv_filenames
      raise ArgumentError, "csv_filenames must be a list of filenames"
    end
  end

  def perform_uploads
    opts.csv_filenames.each do |filename|
      upload_profile_csv(filename)
    end
  end

private

  ## Uploads the profile data in the given CSV to the Appcues API.
  ##
  ## The CSV should begin with a row of headers, and one of these headers
  ## must be named something like `user_id` or `userId`.
  ## Other header names are treated as attribute names.
  ##
  ## Numeric, boolean, and null values in this CSV will be converted to their
  ## appropriate data type.
  def upload_profile_csv(csv_filename)
    display_filename = csv_filename == '-' ? "STDIN" : "'#{csv_filename}'"

    debug "Uploading profiles from #{display_filename} for account #{opts.account_id}..."

    user_id_column = nil
    user_activities = []

    fh = STDIN
    fh = File.open(csv_filename, 'r') if csv_filename != '-'

    CSV.new(fh, headers: true).each do |row|
      row_hash = row.to_h

      if !user_id_column
        user_id_column = get_user_id_column(row_hash)
      end

      user_id = row_hash.delete(user_id_column)
      profile_update = cast_data_types(row_hash)

      user_activities << UserActivity.new(opts.account_id, user_id, profile_update, [])
    end

    fh.close

    make_activity_requests(user_activities)

    debug "Done processing #{display_filename}."
  end

  ## Applies the given UserActivity updates to the Appcues API.
  ## Retries failed requests, indefinitely.
  def make_activity_requests(user_activities)
    failed_uas = []

    user_activities.each do |ua|
      resp = make_activity_request(ua)
      if resp.code.to_i / 100 == 2
        debug "request for user_id #{ua.user_id} was successful"
      else
        debug "request for user_id #{ua.user_id} failed with code #{resp.code} -- retrying later"
        failed_uas << ua
      end
    end

    if failed_uas.count > 0
      debug "retrying #{failed_uas.count} requests."
      make_activity_requests(failed_uas)
    end
  end

  ## Returns a new profile_update hash where boolean and numeric values
  ## are cast out of String format.  Leaves other values alone.
  def cast_data_types(profile_update)
    output = {}
    profile_update.each do |key, value|
      output[key] =
        case value
        when 'null'
          nil
        when 'true'
          true
        when 'false'
          false
        when /^ -? \d* \. \d+ (?: [eE] [+-]? \d+)? $/x  # float
          value.to_f
        when /^ -? \d+ $/x  # integer
          value.to_i
        else
          value
        end
    end
    output
  end

  ## Detects and returns the name used in the CSV header to identify user ID.
  ## Raises an exception if we can't find it.
  def get_user_id_column(row_hash)
    row_hash.keys.each do |key|
      canonical_key = key.gsub(/[^a-zA-Z]/, '').downcase
      return key if canonical_key == 'userid'
    end
    raise ArgumentError, "couldn't detect user ID column"
  end

  ## Prints a message to STDERR unless we're running in quiet mode.
  def debug(msg)
    STDERR.puts(msg) if !self.opts.quiet
  end

  ## Returns the base URL for the Appcues API.
  def appcues_api_url
    ENV['APPCUES_API_URL'] || "https://api.appcues.com"
  end

  ## Returns a URL for the given Appcues API UserActivity endpoint.
  def activity_url(account_id, user_id)
    "#{appcues_api_url}/v1/accounts/#{account_id}/users/#{user_id}/activity"
  end

  ## Makes a POST request to the Appcues API UserActivity endpoint,
  ## returning the Net::HTTPResponse object.
  def make_activity_request(user_activity)
    url = activity_url(user_activity.account_id, user_activity.user_id)
    post_request(url, {
      "profile_update" => user_activity.profile_update,
      "events" => user_activity.events
    })
  end

  ## Makes a POST request to the given URL,
  ## returning the Net::HTTPResponse object.
  def post_request(url, data, headers = {})
    uri = URI(url)
    use_ssl = uri.scheme == 'https'
    Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl) do |http|
      req_headers = headers.merge({'Content-type' => 'application/json'})
      req = Net::HTTP::Post.new(uri.request_uri, req_headers)
      req.body = JSON.dump(data)
      http.request(req)
    end
  end
end

