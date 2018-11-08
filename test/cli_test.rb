require 'test/unit'
require 'json'
require 'pp'

CMD = "ruby bin/appcues-data-uploader"

class CliTest < Test::Unit::TestCase
  def test_stdin
    verify_test_output(`#{CMD} -a 999 -d -q < test/test.csv`)
    verify_test_output(`#{CMD} -a 999 -d -q - < test/test.csv`)
  end

  def test_filename
    verify_test_output(`#{CMD} -a 999 -d -q test/test.csv`)
  end

  def test_filename_twice
    output = `#{CMD} -a 999 -d -q test/test.csv test/test.csv`
    updates = output.split("\n").map{|line| JSON.parse(line)}
    verify_test_updates(updates[0..2])
    verify_test_updates(updates[3..5])
  end

  def test_filename_and_stdin
    output = `#{CMD} -a 999 -d -q - test/test.csv < test/test.csv`
    updates = output.split("\n").map{|line| JSON.parse(line)}
    verify_test_updates(updates[0..2])
    verify_test_updates(updates[3..5])
  end

  def verify_test_output(output)
    updates = output.split("\n").map{|line| JSON.parse(line)}
    verify_test_updates(updates)
  end

  def verify_test_updates(updates)
    assert updates[0] == {
      "account_id" => "999",
      "user_id" => "123",
      "profile_update" => {
        "numeric" => -0.01,
        "boolean" => true,
        "string" => "decks",
      },
      "events" => [],
    }

    assert updates[1] == {
      "account_id" => "999",
      "user_id" => "Asdf",
      "profile_update" => {
        "numeric" => 22,
        "boolean" => false,
        "string" => "omg",
      },
      "events" => [],
    }

    assert updates[2] == {
      "account_id" => "999",
      "user_id" => "WAT",
      "profile_update" => {
        "numeric" => -2,
        "boolean" => false,
        "string" => "wat",
      },
      "events" => [],
    }
  end
end
