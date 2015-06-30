class Dashing.PagerDuty extends Dashing.Widget

  @accessor 'value', Dashing.AnimatedValue

  constructor: ->
    super

  onData: (data) ->
    node = $(@node)
    value = data.open
    console.log value
    level = switch
      when data.triggered > 0 then 4
      when data.acked > 0 then 2
      else 0

    backgroundClass = "hotness#{level}"
    lastClass = @get "lastClass"
    node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
    @set "value", value
