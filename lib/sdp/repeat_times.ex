defmodule Membrane.Protocol.SDP.RepeatTimes do
  @moduledoc """
  This module represents field of SDP that specifies
  repeat times for a session.

  For more details please see [RFC4566 Section 5.10](https://tools.ietf.org/html/rfc4566#section-5.10).
  """
  use Bunch

  @enforce_keys [:repeat_interval, :active_duration, :offsets]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          repeat_interval: non_neg_integer(),
          active_duration: non_neg_integer(),
          offsets: [non_neg_integer()]
        }

  @unit_mappings %{
    "d" => 86400,
    "h" => 3600,
    "m" => 60,
    "s" => 1
  }

  @valid_keys @unit_mappings |> Map.keys()

  @spec parse(binary()) ::
          {:ok, t()}
          | {:error,
             :duration_nan
             | :interval_nan
             | :no_offsets
             | :malformed_repeat
             | {:invalid_offset | :invalid_unit, binary()}}
  def parse(repeat) do
    case String.split(repeat, " ") do
      [interval, duration | offsets] = as_list ->
        if compact?(as_list) do
          parse_compact(as_list)
        else
          parse_explicit(interval, duration, offsets)
        end

      _ ->
        {:error, :malformed_repeat}
    end
  end

  defp compact?(parts) do
    Enum.any?(parts, fn time ->
      Enum.any?(@valid_keys, fn unit -> String.ends_with?(time, unit) end)
    end)
  end

  defp parse_explicit(_interval, _duration, []), do: {:error, :no_offsets}

  defp parse_explicit(interval, duration, offsets) do
    with {interval, ""} <- Integer.parse(interval),
         {duration, ""} <- Integer.parse(duration),
         {:ok, offsets} <- process_offsets(offsets) do
      %__MODULE__{
        repeat_interval: interval,
        active_duration: duration,
        offsets: offsets
      }
      ~> {:ok, &1}
    else
      {:error, _} = error -> error
      _ -> {:error, :malformed_repeat}
    end
  end

  defp process_offsets(offsets, acc \\ [])
  defp process_offsets([], acc), do: {:ok, Enum.reverse(acc)}

  defp process_offsets([offset | rest], acc) do
    case Integer.parse(offset) do
      {offset, ""} when offset >= 0 -> process_offsets(rest, [offset | acc])
      {_, _} -> {:error, {:invalid_offset, offset}}
    end
  end

  defp parse_compact(list) do
    list
    |> decode_compact()
    ~>> (result when is_list(result) -> result |> Enum.reverse() |> build_compact())
  end

  defp decode_compact(list) do
    Enum.reduce_while(list, [], fn
      "0", acc ->
        {:cont, [0 | acc]}

      elem, acc ->
        case Integer.parse(elem) do
          {value, unit} when unit in @valid_keys ->
            time = value * @unit_mappings[unit]
            {:cont, [time | acc]}

          {_, invalid_unit} ->
            {:error, {:invalid_unit, invalid_unit}}
            ~> {:halt, &1}
        end
    end)
  end

  defp build_compact(list)
  defp build_compact([_, _]), do: {:error, :no_offsets}

  defp build_compact([interval, duration | offsets]) do
    %__MODULE__{
      repeat_interval: interval,
      active_duration: duration,
      offsets: offsets
    }
    ~> {:ok, &1}
  end
end
