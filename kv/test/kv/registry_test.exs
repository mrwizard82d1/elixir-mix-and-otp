defmodule KV.RegistryTest do
  use ExUnit.Case

  @moduletag :capture_log

  doctest Registry

  test "module exists" do
    assert is_list(KV.Registry.module_info())
  end

  # Ensure that the GenServer, `KV.Registry`, is started before tests.
  setup do
    # `start_supervised!` is a function injected by `ExUnit.Case`. This function starts the server and links
    # the unit test process to that server. This linkage allows the unit test framework to stop and restart
    # the server between each and every test.
    registry = start_supervised!(KV.Registry)
    %{registry: registry}
  end

  test "spawns buckets", %{registry: registry} do
    # Shopping **does not** exist when server started
    assert KV.Registry.lookup(registry, "shopping") == :error

    # Can find the created "shopping" bucket
    KV.Registry.create(registry, "shopping")
    assert {:ok, bucket} = KV.Registry.lookup(registry, "shopping")

    # Now that we have the "shopping" bucket, can I add an item
    KV.Bucket.put(bucket, "milk", 1)
    assert KV.Bucket.get(bucket, "milk") == 1
  end
end
