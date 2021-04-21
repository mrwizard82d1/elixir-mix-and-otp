defmodule KV.Registry do
  # Inject the `GenServer` behaviour
  use GenServer

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the bucket PID for `name` stored in `server`.
  """
  def lookup(server, name) do
    GenServer.call(server, {:lookup, name})
  end

  @doc """
  Ensures that a bucket associated with `name` exists on `server`.
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  ## Defining GenServer callbacks

  # Initialize the server (with an empty registry
  # The `@impl true` directive informs the compiler that the subsequent function is a callback. If we make a
  # mistake in the name or in the number of arguments, the **compiler** will detect this issue, warn us of the
  # issue, and print out a list of valid callbacks.
  @impl true
  def init(:ok) do
    names = %{}
    refs = %{}
    {:ok, {names, refs}}
  end

  # Handle a lookup request for `name`
  @impl true
  def handle_call({:lookup, name}, _from, state) do
    {names, _} = state
    {:reply, Map.fetch(names, name), state}
  end

  @impl true
  def handle_cast({:create, name}, {names, refs}) do
    if Map.has_key?(names, name) do
      {:noreply, {names, refs}}
    else
      {:ok, pid} = DynamicSupervisor.start_child(KV.BucketSupervisor, KV.Bucket)
      ref = Process.monitor(pid)
      updated_refs = Map.put(refs, ref, name)
      updated_names = Map.put(names, name, pid)
      {:noreply, {updated_names, updated_refs}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    {name, refs} = Map.pop(refs, ref)
    updated_names = Map.delete(names, name)
    {:noreply, {updated_names, refs}}
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect msg
    {:noreply, state}
  end
end
