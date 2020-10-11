defmodule UXID.Decoder do
  @moduledoc """
  Decodes strings into UXID structs
  """

  @blank_error_message "input is required"
  @max_allowed_time 281_474_976_710_655

  @base32_regex ~r/^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]+$/

  alias UXID.CrockfordBase32

  defmodule MissingInputError do
    defexception [:message]

    def exception do
      %MissingInputError{message: "input is required"}
    end
  end

  defmodule InvalidBase32Error do
    defexception [:field, :input, :message]

    def exception({field, input}) do
      msg = "expected #{field} to be a Base32 encoded string, got: '#{input}'"
      %InvalidBase32Error{field: field, input: input, message: msg}
    end
  end

  defmodule MaxTimeExceededError do
    defexception [:message, :time]

    def exception(time) do
      msg = "the time cannot be greater than 2^48, got: #{time}"
      %MaxTimeExceededError{message: msg, time: time}
    end
  end

  def process(""), do: {:error, @blank_error_message}
  def process(string) when is_nil(string), do: {:error, @blank_error_message}

  def process(string) do
    uxid =
      string
      |> validate_input
      |> parse_fields
      |> validate_fields

    {:ok, uxid}
  rescue
    e in [InvalidBase32Error, MaxTimeExceededError] -> {:error, e.message}
  end

  defp parse_fields(string) do
    decoded = CrockfordBase32.decode!(string)

    <<_::2, time::unsigned-size(48), randomness::bitstring>> = decoded

    %UXID{
      encoded: string,
      decoded: decoded,
      time: time,
      randomness: randomness
    }
  end

  defp validate_input(string) do
    if !Regex.match?(@base32_regex, string),
      do: raise(InvalidBase32Error, {"input", string})

    string
  end

  defp validate_fields(%UXID{time: time} = uxid) do
    if time > @max_allowed_time,
      do: raise(MaxTimeExceededError, time)

    uxid
  end
end
