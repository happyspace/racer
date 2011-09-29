Field = module.exports = (@model, @path, @version, @type) ->
  @type ||= require 'share/lib/types/text'
  # @type.apply(snapshot, op)
  # @type.transform(op1, op2, side)
  # @type.normalize(op)
  # @type.create() -> ''

  @snapshot = null
  @queue = []
  @pendingOp = null
  @inflightOp = null
  @serverOps = {}

  self = this
  @model.on 'remoteop', (op) ->
    for {p, i, d} in op
      if i
        self.emit 'insertOT', i, p
      else
        self.emit 'delOT', d, p
    return

  # Decorate model prototype
  model.insertOT = (path, str, pos, callback) ->
    # TODO Still need to normalize path
    field = @otFields[path] ||= new OT @, path
    pos ?= 0
    op = [ { p: pos, i: str } ]
    op.callback = callback if callback
    field.submitOp op

  # Decorate adapter

Field:: =
  onRemoteOp: (op, v) ->
    # TODO
    return if v < @version
    throw new Error "Expected version #{@version} but got #{v}" unless v == @version
    docOp = @serverOps[@version] = op
    if inflightOp
      [inflightOp, docOp] = xf inflightOp, docOp
    if pendingOp
      [pendingOp, docOp] = xf pendingOp, docOp

    @version++
    otApply docOp, true

  otApply: (docOp, isRemote) ->
    oldSnapshot = @snapshot
    @snapshot = @type.apply oldSnapshot, docOp
    @model.emit 'remoteop', docOp, oldSnapshot if isRemote
    @model.emit 'change', docOp, oldSnapshot

  submitOp: (op) ->
    type = @type
    op = type.normalize op
    @snapshot = type.apply @snapshot, op
    @pendingOp = if @pendingOp then type.compose @pendingOp, op else op
    setTimeout @flush, 0

  flush: ->
    if @inflightOp == null && @pendingOp != null
      inflightOp = pendingOp
      pendingOp = null

      # @model.socket.send msg, (err, res) ->
      @model.socket.emit 'otOp', path: @path, op: inflightOp, v: @version

  xf: (client, server) ->
    client_ = @type.transform client, server, 'left'
    server_ = @type.transform server, client, 'right'
    return [client_, server_]

Field.field = (initVal) -> $ot: initVal
