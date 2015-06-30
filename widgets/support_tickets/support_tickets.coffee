class Dashing.SupportTickets extends Dashing.Widget

  @accessor 'value', Dashing.AnimatedValue

  constructor: ->
    super

  onData: (data) ->
    node = $(@node)
    issues = data.issues
    console.log issues

    warn = false
    late = false

    for i in issues
      unless i.classification
        warn = true

      if i.fixUrgency == 'warning'
        warn = true
      else if i.fixUrgency == 'late'
        late = true

    level = switch
      when late > 0 then 4
      when warn then 2
      else 0
  
    backgroundClass = "hotness#{level}"
    lastClass = @get "lastClass"
    node.toggleClass "#{lastClass} #{backgroundClass}"
    @set "lastClass", backgroundClass
    @set "value", (issues || []).length
