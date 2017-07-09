defmodule KRPCProtocol.Encoder do

  @moduledoc ~S"""
  KRPCProtocol.Encoder provides functions to encode mainline DHT messages.
  """

  #########
  # Error #
  #########

  def encode(:error, code: code, msg: msg, tid: tid) do
    Bencodex.encode %{"y" => "e", "t" => tid, "e" => [code, msg]}
  end

  ###########
  # Queries #
  ###########

  @doc ~S"""
  This function returns a bencoded Mainline DHT ping query. It needs a 20 bytes
  node ID an argument. The tid (transaction id) is optional.

  ## Example
  iex> KRPCProtocol.encode(:ping, tid: "aa", node_id: node_id)
  """
  def encode(:ping, tid: tid, node_id: node_id) do
    gen_dht_query "ping", tid, %{"id" => node_id}
  end
  def encode(:ping, node_id: node_id) do
    encode(:ping, tid: gen_tid(), node_id: node_id)
  end


  @doc ~S"""
  This function returns a bencoded Mainline DHT find_node query. It
  needs a 20 bytes node ID and a 20 bytes target ID as an argument.

  ## Example
  iex> KRPCProtocol.encode(:find_node, node_id: node_id, target: info_hash)
  """
  def encode(:find_node, node_id: id, target: target) do
    encode(:find_node, tid: gen_tid(), node_id: id, target: target, want: "n4")
  end

  def encode(:find_node, node_id: id, target: target, want: want) do
    encode(:find_node, tid: gen_tid(), node_id: id, target: target, want: want)
  end

  def encode(:find_node, tid: tid, node_id: id, target: target) do
    encode(:find_node, tid: tid, node_id: id, target: target, want: "n4")
  end

  def encode(:find_node, tid: tid, node_id: id, target: target, want: want) do
    gen_dht_query "find_node", tid, %{"id" => id, "target" => target, "want" => want}
  end


  @doc "TODO"

  def encode(:get_peers, args) do
    options = args[:node_id]
    |> query_dict(args[:info_hash])
    |> add_option_if_defined(:scrape, args[:scrape])
    |> add_option_if_defined(:noseed, args[:noseed])
    |> add_option_if_defined(:want,   args[:want])

    gen_dht_query("get_peers", args[:tid] || gen_tid(), options)
  end

  def encode(:announce_peer, args) do
    options = args[:node_id]
    |> query_dict(args[:info_hash])
    |> add_option_if_defined(:implied_port, args[:implied_port])
    |> add_option_if_defined(:port, args[:port])
    |> add_option_if_defined(:token, args[:token])

    gen_dht_query("announce_peer", args[:tid] || gen_tid(), options)
  end

  ###########
  # Replies #
  ###########

  def encode(:ping_reply, tid: tid, node_id: node_id) do
    gen_dht_response %{"id" => node_id}, tid
  end

  def encode(:find_node_reply, node_id: id, nodes: nodes, tid: tid) do
    gen_dht_response %{"id" => id, "nodes" => compact_format(nodes)}, tid
  end

  def encode(:find_node_reply, node_id: id, nodes6: nodes, tid: tid) do
    gen_dht_response %{"id" => id, "nodes6" => compact_format(nodes)}, tid
  end

  def encode(:get_peers_reply, node_id: id, nodes: nodes, tid: tid, token: token) do
    gen_dht_response %{
      "id"    => id,
      "token" => token,
      "nodes" => compact_format(nodes)
    }, tid
  end

  def encode(:get_peers_reply, node_id: id, values: values, tid: tid, token: token) do
    gen_dht_response %{
      "id"     => id,
      "token"  => token,
      "values" => compact_format_values(values)
    }, tid
  end

  @doc ~S"""
  This function generates a 16 bit (2 byte) random transaction ID and converts
  it to a binary and returns it. This transaction ID is echoed in the response.
  """
  def gen_tid do
    :rand.seed(:exs64, :os.timestamp)

    fn -> :rand.uniform 255 end
    |> Stream.repeatedly
    |> Enum.take(2)
    |> :binary.list_to_bin
  end

  #####################
  # Private Functions #
  #####################

  # This function converts a list of nodes with the format {ip, port} in the
  # compact format.
  defp compact_format_values(nodes), do: compact_format_values(nodes, "")
  defp compact_format_values([], result), do: result
  defp compact_format_values([head | tail], result) do
    {ip, port} = head

    result = result <> node_to_binary(ip, port)
    compact_format_values(tail, result)
  end

  # This function converts a list of nodes with the format {node_id, ip, port}
  # in the compact format.
  defp compact_format(nodes), do: compact_format(nodes, "")
  defp compact_format([], result), do: result
  defp compact_format([head | tail], result) do
    {node_id, ip, port} = head

    result = result <> node_id <> node_to_binary(ip, port)
    compact_format(tail, result)
  end

  defp gen_dht_query(command, tid, options) when is_map(options) do
    Bencodex.encode %{"y" => "q", "t" => tid, "q" => command, "a" => options}
  end

  defp gen_dht_response(options, tid) when is_map(options) do
    Bencodex.encode %{"y" => "r", "t" => tid, "r" => options}
  end

  # IPv4 address
  def node_to_binary({oct1, oct2, oct3, oct4}, port) do
    <<oct1 :: 8, oct2 :: 8, oct3 :: 8, oct4 :: 8, port :: 16>>
  end

  # IPv6 address
  def node_to_binary(ip, port) when tuple_size(ip) == 8 do
    ipstr = ip
    |> Tuple.to_list
    |> Enum.map(&<<_oct1 :: 8, _oct2 :: 8>> = << &1 :: 16>>)
    |> Enum.reduce(fn(x, y) -> y <> x end)

    << ipstr :: binary, port :: 16 >>
  end

  # This function returns a bencoded mainline DHT get_peers query. It
  # needs a 20 bytes node ID and a 20 bytes info_hash as an
  # argument. Optional arguments are [want: "n6", scrape: true]
  defp add_option_if_defined(dict, _key, nil), do: dict
  defp add_option_if_defined(dict, key, true), do: Map.put_new(dict, to_string(key), 1)
  defp add_option_if_defined(dict, key, value) do
    Map.put_new(dict, to_string(key), value)
  end


  defp query_dict(id, info_hash) do
    %{"id" => id, "info_hash" => info_hash}
  end

end
