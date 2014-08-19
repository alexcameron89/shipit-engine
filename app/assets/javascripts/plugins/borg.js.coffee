class ContainersRestartWidget
  active: false

  constructor: ->
    @tasks = {}

  appendTo: (@$container) ->

  getTask: (host) ->
    @tasks[host] ||= new ContainerView(@$container, host)

  addHeading: ->
    @heading = $("<h2 class='task-group-heading'>Restarting Containers</h2>")
    @heading.appendTo(@$container)

  activate: ->
    return if @active
    @addHeading()
    @active = true

  update: (text) ->
    new CapistranoParser(text).eachMessage (log) =>
      if match = log.output.match(/\[(\d+)\/(\d+)\] Restarting/)
        @activate()
        @getTask(log.host).update
          numPending: match[1]
          numLights: match[2]
      else if match = log.output.match(/\[(\d+)\/(\d+)\] Successfully Restarted/)
        @getTask(log.host).update
          numDone: match[1]
          numLights: match[2]
      else if match = log.output.match(/\[(\d+)\/(\d+)\] Unable to restart/)
        @getTask(log.host).update(numPending: match[1], numLights: match[2]).fail()
    null


class ContainerView
  TEMPLATE = $.trim """
    <div class="task-lights">
      <span class="task-lights-text">
        <span class="task-lights-title"></span>
      </span>
      <span class="task-lights-boxes"></span>
    </div>
  """
  numLights: 0
  numPending: 0
  numDone: 0

  constructor: (@$container, host) ->
    @$element = $(TEMPLATE)
    title = host.split('.')[0]
    @$element.find('.task-lights-title').text(title)
    @insertSorted(@$element, title)

  insertSorted: (toInsert, title) ->
    inserted = false
    $('.task-lights',@$container).each ->
      title2 = $('.task-lights-title',this).text()
      # Sort shorter names first, so that the sort ends up 
      # like [sb1,sb2,sb10] not [sb1,sb10,sb2]
      if title2.length > title.length || (title2 > title && title2.length == title.length)
        toInsert.insertBefore(this)
        inserted = true
        return false
    toInsert.appendTo(@$container) unless inserted

  update: (attrs) ->
    $.extend(this, attrs)
    boxes = document.createDocumentFragment();
    for i in [1..(+@numLights)]
      status = if i <= @numDone
        'up'
      else if i <= @numPending
        'partial'
      else
        'neutral'
      $('<span>').addClass("task-lights-box box-#{status}").appendTo(boxes)
    @$element.find('.task-lights-boxes').empty().append(boxes)
    this

  fail: ->
    @$element.addClass('task-failed')


restartWidget = new ContainersRestartWidget()

ChunkPoller.prependFormatter (chunk) ->
  restartWidget.update(chunk)
  false

Sidebar.registerPlugin(restartWidget)