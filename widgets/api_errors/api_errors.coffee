class Dashing.ApiErrors extends Dashing.Widget

  constructor: ->
    super

  onData: (data) ->
    node = $(@node)
    level = 0

    backgroundClass = "hotness#{level}"
    lastClass = @get "lastClass"
    node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
