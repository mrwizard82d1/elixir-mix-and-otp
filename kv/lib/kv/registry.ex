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
    {:ok, %{}}
  end

  # Handle a lookup request for `name`
  @impl true
  def handle_call({:lookup, name}, _from, names) do
    {:reply, Map.fetch(names, name), names}
  end

  @impl true
  def handle_cast({:create, name}, names) do
    if Map.has_key?(names, name) do
      {:noreply, names}
    else
      {:ok, bucket} = KV.Bucket.start_link([])
      {:noreply, Map.put(names, name, bucket)}
    end
  end
end
