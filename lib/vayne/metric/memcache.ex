defmodule Vayne.Metric.Memcache do

  @behaviour Vayne.Task.Metric

  @moduledoc """
  Get Memcache metrics
  """

  @doc """
  Params below:

  * `hostname`: Memcache hostname.Required.
  * `port`: Memcache port. Not required, default 11211.

  """

  def init(params) do
    if Map.has_key?(params, "hostname") do
      params = Enum.reduce(~w(hostname port), [], fn (k, acc) ->
        if params[k] do
          Keyword.put(acc, String.to_atom(k), params[k])
        else
          acc
        end
      end)
      case Memcache.start_link(params) do
        {:ok, conn} -> {:ok, conn}
        {:error, error} -> {:error, error}
      end
    else
      {:error, "hostname is required"}
    end
  end

  def run(conn, log_func) do
    Process.flag(:trap_exit, true)
    metric = try do
      case Memcache.stat(conn) do
        {:error, reason} -> 
          log_func.("stat err: #{inspect reason}")
          %{"memcache.alive" => 0}
        {:ok, dict} -> 
          hash = get_numbers(dict)
          hash |> used_mem_per(hash) |> Map.merge(%{"memcache.alive" => 1})
      end
    catch
      :exit, value -> 
        log_func.("exit err: #{inspect value}")
        %{"memcache.alive" => 0}
    end
    {:ok, metric}
  end

  def clean(conn) do
    Process.exit(conn, :kill)
    :ok
  end

  defp get_numbers(hash) do
    hash
    |> Map.to_list
    |> Enum.reduce(%{}, fn ({k, v}, acc) ->
      value = try_parse(v)
      if is_number(value) do
        Map.put(acc, k, value)
      else
        acc
      end
    end)
  end

  defp used_mem_per(acc, hash) do
    if Enum.all?(~w(bytes limit_maxbytes), &(is_number(hash[&1]))) do
      used_memory_percent = hash["bytes"] / hash["limit_maxbytes"]
      Map.put(acc, "used_memory_percent", Float.floor(used_memory_percent, 3))
    else
      acc
    end
  end

  defp try_parse(value) when is_binary(value) do
    case Integer.parse(value) do
      {v, _} -> v
      _      -> value
    end
  end
  defp try_parse(value), do: value
end

