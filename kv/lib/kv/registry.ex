defmodule KV.Registry do
  # Inject the `GenServer` behaviour
  use GenServer

  ## Client API

  @doc """
  Starts the registry with the given options.

  `name` is always required.
  """
  def start_link(opts) do
    # Pass the value of the `:name` key to `GenServer.init/3`. This value allows clients to identify the
    # server on subsequent calls.
    server_name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, server_name, opts)
  end

  @doc """
  Looks up the bucket PID for `name` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def lookup(server, name) do
    # Lookup is now performed directly in ETS, **without** accessing the server.
    case :ets.lookup(server, name) do
      [{^name, pid}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Ensures that a bucket associated with `name` exists on `server`.
  """
  def create(server, name) do
    # Make this a `call` to prevent returning **before** the bucket is created in ETS.
    GenServer.call(server, {:create, name})
  end

  ## Defining GenServer callbacks

  # Initialize the server (with an empty registry
  # The `@impl true` directive informs the compiler that the subsequent function is a callback. If we make a
  # mistake in the name or in the number of arguments, the **compiler** will detect this issue, warn us of the
  # issue, and print out a list of valid callbacks.
  @impl true
  def init(table) do
    # Replace the `names` Map with an ETS table. The name of the table in ETS is `table`.
    names = :ets.new(table, [:named_table, read_concurrency: true])
    refs = %{}
    {:ok, {names, refs}}
  end

  @impl true
  def handle_call({:create, name}, _from, {names, refs}) do
    # Note that a call provides "back pressure" since the client **must** wait for the response.
    case lookup(names, name) do
      # `name` **already** exists in ETS so we do not reply but only update the state. (Remember, a client
      # must **already** know the name of the table set at creation.
      {:ok, _pid} -> {:noreply, {names, refs}}
      :error ->
        # `name` does not exist in ETS, so create the bucket...
        {:ok, pid} = DynamicSupervisor.start_child(KV.BucketSupervisor, KV.Bucket)
        ref = Process.monitor(pid)
        updated_refs = Map.put(refs, ref, name)

        # ...insert the bucket into ETS associated with `name`,
        :ets.insert(names, {name, pid})

        # ...reply with the process ID of the bucket and update the state.
        {:reply, pid, {names, updated_refs}}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    {name, refs} = Map.pop(refs, ref)
    # Delete the bucket from the ETS table instead of from the internal map...
    :ets.delete(names, name)

    # ...and return the "updated" state
    {:noreply, {names, refs}}
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect msg
    {:noreply, state}
  end
end
