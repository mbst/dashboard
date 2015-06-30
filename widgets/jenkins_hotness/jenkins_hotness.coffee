class Dashing.JenkinsHotness extends Dashing.Widget

  @accessor 'value', Dashing.AnimatedValue

  constructor: ->
    super

  onData: (data) ->
    node = $(@node)
    value = (data.failedJobs || []).length
    cool = parseInt node.data "cool"
    warm = parseInt node.data "warm"
    level = switch
      when value <= cool then 0
      when value >= warm then 4
      else 
        bucketSize = (warm - cool) / 3 # Total # of colours in middle
        Math.ceil (value - cool) / bucketSize
  
    backgroundClass = "hotness#{level}"
    lastClass = @get "lastClass"
    node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
    @set "value", value
