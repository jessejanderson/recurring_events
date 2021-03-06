defmodule RecurringEvents do
  @moduledoc """
  *RecurringEvents* is an Elixir library providing recurring events support
  (duh!).

  It loosely follows
  [iCal Recurrence rule specification](http://www.kanzaki.com/docs/ical/rrule.html)
  [RFC 2445](https://tools.ietf.org/html/rfc2445).

  Currently, it is ignoring time but if DateTime or NaiveDateTime structure
  is used time will be preserved (see below).

      iex> RecurringEvents.take(~D[2016-12-07], %{freq: :daily}, 3)
      [~D[2016-12-07], ~D[2016-12-08], ~D[2016-12-09]]

      iex> RecurringEvents.take(~N[2016-01-17 12:21:06], %{freq: :weekly}, 2)
      [~N[2016-01-17 12:21:06], ~N[2016-01-24 12:21:06]]

  Currently supported rules

    - `:count` - how many occurences should be return
    - `:interval` - how often recurrence rule repeats
    - `:freq` - this is the only required rule, possible values: `:yearly`,
      `:monthly`, `:weekly`, `:daily`
    - `:by_month` - month number or list of month numbers
    - `:by_day` - day or list of days, possible values: `:monday`, `:tuesday`,
      `:wednesday`, `:thursday`, `:friday`, `:saturday`, `:sunday`
    - `:week_start` - start day of the week, see `:by_day` for possible values

  For more usage examples, please, refer to
  [tests](https://github.com/pbogut/recurring_events/blob/master/test/ical_rrul_test.exs)

  """

  alias RecurringEvents.{Date, Guards,
                         Yearly, Monthly, Weekly, Daily,
                         ByMonth, ByDay}
  use Guards

  @doc """
  Returns stream of recurring events based on date and rules

  # Example

      iex> RecurringEvents.unfold(~D[2014-06-07], %{freq: :yearly})
      ...> |> Enum.take(3)
      [~D[2014-06-07], ~D[2015-06-07], ~D[2016-06-07]]

  """
  def unfold(_date, %{count: _, until: _}) do
    raise ArgumentError, message: "Can have either, count or until"
  end
  def unfold(date, %{freq: freq} = rules) when is_freq_valid(freq) do
    do_unfold(date, rules)
  end
  def unfold(_date, %{freq: _}) do
    raise ArgumentError, message: "Frequency is invalid"
  end
  def unfold(_date, _rrule) do
    raise ArgumentError, message: "Frequency is required"
  end

  @doc """
  Returns list of recurring events based on date and rules

  # Example

      iex> RecurringEvents.take(~D[2015-09-13], %{freq: :monthly}, 4)
      [~D[2015-09-13], ~D[2015-10-13], ~D[2015-11-13], ~D[2015-12-13]]

  """
  def take(date, rules, count) do
    date |> do_unfold(rules) |> Enum.take(count)
  end

  defp do_unfold(date, %{freq: freq} = rules) do
    date
    |> get_freq_module(freq).unfold(rules)
    |> Stream.flat_map(&ByMonth.unfold &1, rules)
    |> Stream.flat_map(&ByDay.unfold &1, rules)
    |> drop_before(date)
    |> prepend(date)
    |> drop_after(rules)
  end

  defp drop_before(list, date) do
    Stream.drop_while(list, &Date.compare(date, &1) != :lt)
  end

  defp drop_after(list, %{until: date}) do
    Stream.take_while(list, &Date.compare(date, &1) != :lt)
  end
  defp drop_after(list, %{count: count}), do: Stream.take(list, count)
  defp drop_after(list, %{}), do: list

  defp prepend(list, element), do: Stream.concat([element], list)

  defp get_freq_module(:yearly), do: Yearly
  defp get_freq_module(:monthly), do: Monthly
  defp get_freq_module(:weekly), do: Weekly
  defp get_freq_module(:daily), do: Daily
end
