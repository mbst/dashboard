class Dashing.SensuGrid extends Dashing.Widget

  constructor: ->
    super

  onData: (data) ->
    node = $(@node)
    level = switch
      when data.stage.critical > 0 or data.prod.critical > 0 then 4
      when data.stage.warning > 0 or data.prod.warning > 0 then 2
      else 0
  
    backgroundClass = "hotness#{level}"
    lastClass = @get "lastClass"
    node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
