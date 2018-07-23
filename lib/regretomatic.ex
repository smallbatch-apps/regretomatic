defmodule Regretomatic do

  alias Cldr.Number, as: NumberFormat

  @moduledoc """
  Documentation for Regretomatic.
  """

  def missed_out(symbol, date, number \\ 1) do
    case symbol_date_difference(symbol, date, number) do
      {:positive, amount} -> "Wow, you actually dodged a bullet, you would have lost $#{amount}!"
      {:negative, amount} -> "Ouch. You could have had $#{amount} right now. Think about all the things you could have bought."
    end
  end

  def bought_high(symbol, date, number \\ 1) do
    case symbol_date_difference(symbol, date, number) do
      {:positive, amount} -> "Goddamn, dropped by $#{amount} since then. Bet you're glad you only bought #{number}?"
      {:negative, amount} -> "Nice, you actually made $#{amount}!"
    end
  end

  defp symbol_date_difference(symbol, date, number) do
    symbol_map = load_file(symbol)

    {:ok, date_rate} = symbol_map |> get_symbol_rate_for_date(symbol, date)
    {:ok, current_rate} = symbol_map |> get_symbol_rate_today(symbol)
    
    rate_calculation(date_rate, current_rate, number)
  end

  defp rate_calculation(date_rate, current_rate, number) do
    ((date_rate - current_rate) * number) |> rate_tuple
  end

  defp rate_tuple(difference) do
    {:ok, formatted_value} = difference |> trunc |> abs |> NumberFormat.to_string

    case difference do
      diff when diff > 0 -> {:positive, formatted_value}
      _diff -> {:negative, formatted_value}
    end
  end

  defp load_file(symbol) do
    read_file_for(symbol)
    |> Enum.map(&create_date_pair(&1))
    |> Enum.into(%{})
  end

  defp read_file_for(symbol) do
    File.touch("#{symbol}.txt")
    File.stream!("#{symbol}.txt")
  end

  defp create_date_pair(line) do
    line 
    |> String.replace("\r", "") 
    |> String.replace("\n", "")
    |> String.split(",")
    |> List.to_tuple
  end

  defp get_date_value(map, symbol, date) do
    case Map.fetch(map, date) do
      :error -> get_api_value(symbol, date) 
        |> update_map_from_api(map)
        |> write_map_to_file(symbol)
        |> Map.fetch(date)
      {:ok, rate} -> {:ok, String.to_float(rate)}
    end
  end

  defp get_api_value(symbol, date) do
    api_url = "https://rest.coinapi.io/v1/exchangerate/#{symbol}/USD?time=#{date}"
    headers = [{:"X-CoinAPI-Key", ""}, {:"Accept-Encoding", "deflate, gzip"}, {:"Accept", "application/json"}]
    HTTPoison.start
    case HTTPoison.get(api_url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> Poison.decode!(:zlib.gunzip(body))
      {:ok, %HTTPoison.Response{status_code: 404}} -> IO.puts "Not found :("
      {:error, %HTTPoison.Error{reason: reason}} -> IO.inspect reason
    end
  end

  defp update_map_from_api(json, map) do
    {:ok, time} = Map.fetch(json, "time")
    {:ok, rate} = Map.fetch(json, "rate")

    date_string = Date.from_iso8601!(String.slice(time, 0..9))
      |> Date.add(1)
      |> Date.to_string

    Map.put(map, date_string, rate)
  end

  defp write_map_to_file(map, symbol) do
    list = Enum.map(map, fn {k, v} -> "#{k},#{v}" end)
      |> Enum.join("\n")

    File.write("#{symbol}.txt", list)
    map
  end

  defp get_symbol_rate_for_date(map, symbol, date) do
    get_date_value(map, symbol, date)
  end

  defp get_symbol_rate_today(map, symbol) do
    get_date_value(map, symbol, Date.utc_today |> Date.to_string)
  end

end
