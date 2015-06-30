class Dashing.Graph extends Dashing.Widget

  Averages = [1,5]

  @accessor 'averages', ->
    points = @get('points')
    if points
      averages = for a in Averages
        {mins: a, avg: _.sum(points[-(a+1)..], (p)->p.y)/a}
      return _(averages).map((a)-> "<span class=\"avg\"><span class=\"value\">#{Math.round(a.avg)}</span><br><span class=\"duration\">ms (#{a.mins}m)</span></span>").join("\n")
    else
      '???'

  ready: ->
    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    @graph = new Rickshaw.Graph(
      element: @node
      width: width
      height: height
      renderer: @get("graphtype")
      series: [
        {
        color: "#fff",
        data: [{x:0, y:0}]
        }
      ]
      max: @max
    )

    @graph.series[0].data = @get('points') if @get('points')

    x_axis = new Rickshaw.Graph.Axis.Time(graph: @graph)
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, tickFormat: Rickshaw.Fixtures.Number.formatKMBT)
    @graph.render()

  onData: (data) ->
    if @graph
      @graph.series[0].data = data.points
      @graph.render()
