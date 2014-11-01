###
# drawtree.coffee
# Quick-and-dirty tree visualization
#
# Copyright (c) 2013 Anthony Bau
# MIT License.
###
PADDING = 10

exports = {}

exports.Tree = class Tree
  constructor: (@parent, @value, @depth, @color = '#FFF', @data = null) ->
    if @parent? then @parent.children.push this
    @children = []
    @dimensions = null

  # Rendering capabilities
  computeDimensions: (ctx, fontSize = 20, lineHeight = 20) ->
    ctx.font = "#{fontSize}px Arial"
    width = 0
    topHeight = fontSize + lineHeight
    bottomHeight = 0

    for child in @children
      child.computeDimensions ctx, fontSize, lineHeight
      bottomHeight = Math.max child.dimensions.height, bottomHeight
      width += child.dimensions.width

    if width > (ref = ctx.measureText(@value).width + PADDING)
      @centerChildren = false
    else
      @centerChildren = true
      @childrenWidth = width
      width = ref

    @dimensions = {
      width: width
      height: topHeight + bottomHeight
    }

  drawTreePath: (ctx, fontSize = 20, lineHeight = 20, coords = {x:20, y:20}) ->
    ctx.strokeStyle = '#000'

    @rectX = coords.x + (@dimensions.width - ctx.measureText(@value).width) / 2
    @rectY = coords.y - fontSize / 2

    top = coords.y + fontSize + lineHeight
    runningLeft = coords.x

    if @centerChildren
      runningLeft += (@dimensions.width - @childrenWidth) / 2

    for child in @children
      child.drawTreePath ctx, fontSize, lineHeight, {
        x: runningLeft,
        y: top
      }

      #unless @parent is null
      ctx.strokeStyle = '#000'

      ctx.beginPath()
      ctx.moveTo coords.x + @dimensions.width / 2, coords.y
      ctx.lineTo runningLeft + child.dimensions.width / 2, top
      ctx.stroke()

      runningLeft += child.dimensions.width

  drawBoxPath: (ctx, fontSize = 20, lineHeight = 20, coords = {x:20, y:20}) ->
    ctx.strokeStyle = '#000'

    @rectX = coords.x + (@dimensions.width - ctx.measureText(@value).width) / 2
    @rectY = coords.y

    top = coords.y + fontSize + lineHeight
    runningLeft = coords.x

    if @centerChildren
      runningLeft += (@dimensions.width - @childrenWidth) / 2

    for child in @children
      child.drawBoxPath ctx, fontSize, lineHeight, {
        x: runningLeft,
        y: top
      }

      runningLeft += child.dimensions.width

    unless @parent is null
      ctx.strokeStyle = '#000'
      console.log 'stroking rect', @value

      ctx.strokeRect coords.x, coords.y, @dimensions.width, @dimensions.height

      ctx.fillStyle = @color
      ctx.fillRect coords.x, coords.y, @dimensions.width, @dimensions.height

  drawText: (ctx, fontSize = 20, lineHeight = 20) ->
    unless @parent is null
      ctx.strokeStyle = '#000'
      ctx.fillStyle = @color
      ctx.strokeRect @rectX, @rectY, ctx.measureText(@value).width, fontSize
      ctx.fillRect @rectX, @rectY, ctx.measureText(@value).width, fontSize

      ctx.fillStyle = '#000'
      ctx.font = "#{fontSize}px 'Arial'"
      ctx.fillText @value, @rectX, @rectY + fontSize

    for child in @children then child.drawText ctx, fontSize, lineHeight

  drawTree: (ctx, fontSize = 20, lineHeight = 20, coords = {x:20, y:20}) ->
    @computeDimensions ctx, fontSize, lineHeight
    @drawTreePath ctx, fontSize, lineHeight, coords
    @drawText ctx, fontSize, lineHeight, {border: '#000', background: @color}

  drawBox: (ctx, fontSize = 20, lineHeight = 20, coords = {x:20, y:20}) ->
    @computeDimensions ctx, fontSize, lineHeight
    @drawBoxPath ctx, fontSize, lineHeight, coords
    @drawText ctx, fontSize, lineHeight, {
      border: 'transparent',
      background: 'transparent'
    }

  draw: -> @drawTree.apply this, arguments

  getRoot: ->
    head = @
    head = head.parent until head.parent is null
    return head

exports.parseTabdown = (string) ->
  lines = string.split '\n'
  tree = new Tree null, 'root', -1
  for line in lines
    indent = line.length - line.trimLeft().length
    if indent is line.length
      continue
    else if indent > tree.depth
      tree = new Tree tree, line.trimLeft(), indent
    else if indent <= tree.depth
      until tree.depth < indent
        tree = tree.parent
      tree = new Tree tree, line.trimLeft(), indent

  until tree.parent is null
    tree = tree.parent

  return tree

exports.parseLisp = (string) ->
  tree = new Tree null, 'root', 0
  editingHead = false
  for char in string
    switch char
      when '('
        editingHead = true
        tree = new Tree tree, '', tree.depth + 1
      when ')'
        while tree.value.length is 0
          tree.parent.children.splice tree.parent.children.indexOf(tree), 1, tree.children...
          tree = tree.parent
        tree = tree.parent
      when ' ', '\n'
        unless editingHead
          if tree.value.length is 0
            tree.parent.children.splice tree.parent.children.indexOf(tree), 1, tree.children...
          tree = tree.parent
        editingHead = false
        tree = new Tree tree, '', tree.depth + 1
      else
        tree.value += char

  until tree.parent is null
    if tree.value.length is 0
      tree.parent.children.splice tree.parent.children.indexOf(tree), 1, tree.children...
    tree = tree.parent

  return tree

parseCoffee = (node) ->
  root = new Tree null, node.constructor.name
  node.eachChild (child) ->
    newNode = parseCoffee child
    newNode.parent = root
    root.children.push newNode

  return root

exports.parseCoffee = (text) ->
  parseCoffee CoffeeScript.nodes text

window.tabdown = exports

_last = (a) -> a[a.length - 1]

firstNotIn = (prefix, n) ->
  for i in [0...n]
    unless i in prefix
      return i
  return null

available = (prefix, n) ->
  last = _last prefix
  for i in [last...n]
    if i not in prefix
      return true
  return false

nextAvailable = (prefix, n) ->
  last = _last prefix
  for i in [last...n]
    if i not in prefix
      return i
  return null

next = (tree, n) ->
  prefix = tree.data.slice 0

  if prefix.length < n
    prefix.push firstNotIn(prefix, n)
    tree = new Tree tree, _last(prefix), tree.depth + 1, '#F00', prefix
    return tree

  until available(prefix, n) or not tree?
    prefix.pop()
    tree.color = '#FFF'
    tree = tree.parent

  if not tree?
    return null

  prefix[prefix.length - 1] = nextAvailable prefix, n
  tree.color = '#FFF'
  tree = new Tree tree.parent, _last(prefix), tree.depth, '#F00', prefix

  return tree

window.dfsanim = dfsanim = (ctx, n, tree = new Tree(null, '', 0, '#F00', [])) ->
  tree = next tree, n
  if tree?
    ctx.clearRect 0, 0, canvas.width, canvas.height
    tree.getRoot().draw ctx

    setTimeout (-> dfsanim ctx, n, tree), 500

window.binaryanim = binaryanim = (ctx, n, tree = new Tree(null, '', 0, '#F00')) ->
  if tree.value.length is n or tree.children.length is 2
      tree.color = '#FFF'; tree = tree.parent
  else if tree.children.length is 1
    tree = new Tree tree, tree.value + '1', tree.depth + 1, '#F00'
  else if tree.children.length is 0
    tree = new Tree tree, tree.value + '0', tree.depth + 1, '#F00'

  if tree?
    ctx.clearRect 0, 0, canvas.width, canvas.height
    tree.getRoot().draw ctx

    setTimeout (-> binaryanim ctx, n, tree), 500

