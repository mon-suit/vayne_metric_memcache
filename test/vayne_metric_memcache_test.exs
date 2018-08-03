defmodule VayneMetricMemcacheTest do
  use ExUnit.Case, async: false

  require IEx

  @supervisor Vayne.Test.TaskSupervisor

  setup_all do
    :inet_gethost_native.start_link
    Task.Supervisor.start_link(name: @supervisor)
    Process.sleep(1_000)
    :ok
  end

  setup do
    port_count    = length(Port.list())
    ets_count     = length(:ets.all())
    process_count = length(Process.list())
    on_exit "ensure release resource", fn ->
      Process.sleep(1_000)
      assert process_count == length(Process.list())
      assert port_count    == length(Port.list())
      assert ets_count     == length(:ets.all())
    end
  end

  @suc_params %{"hostname" => "127.0.0.1"}
  @port_fail_params %{"hostname" => "127.0.0.1", "port" => 11212}

  test "normal success" do
    task = %Vayne.Task{
      uniqe_key:   "normal success",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Memcache, params: @suc_params},
      export_info:   %{module: Vayne.Export.Console, params: nil}
    }

    async = Task.Supervisor.async_nolink(@supervisor, fn ->
      Vayne.Task.test_task(task)
    end)

    {:ok, metrics} = Task.await(async)
    assert metrics["memcache.alive"] == 1
  end

  test "port fail" do
    task = %Vayne.Task{
      uniqe_key:   "port fail",
      interval:    10,
      metric_info: %{module: Vayne.Metric.Memcache, params: @port_fail_params},
      export_info:   %{module: Vayne.Export.Console, params: nil}
    }

    async = Task.Supervisor.async_nolink(@supervisor, fn ->
      Vayne.Task.test_task(task)
    end)

    {:ok, metrics} = Task.await(async)
    assert metrics["memcache.alive"] == 0
  end

  test "connect wrong server" do
    [
      %{"hostname" => "127.0.0.1", "port" => 3306},
      %{"hostname" => "127.0.0.1", "port" => 6379},
      %{"hostname" => "127.0.0.1", "port" => 27017},
    ]
    |> Enum.map(fn params ->

      task = %Vayne.Task{
        uniqe_key:   "connect failed",
        interval:    10,
        metric_info: %{module: Vayne.Metric.Memcache, params: params},
        export_info:   %{module: Vayne.Export.Console, params: nil}
      }

      async = Task.Supervisor.async_nolink(@supervisor, fn ->
        Vayne.Task.test_task(task)
      end)

      {:ok, metrics} = Task.await(async, :infinity)
      assert metrics["memcache.alive"] == 0
    end)
  end
end
