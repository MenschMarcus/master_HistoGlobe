window.HG ?= {}

class HG.HiventInfoPopover

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hiventHandle, container, @_hgInstance, hiventIndex, showArrow) ->

    @_visible = false
    @_multimediaController = hgInstance.multimediaController

    @_description_length = 285

    #@_hivent_ID = @_hiventHandle.getHivent().id.substring(2)
    #@_multimedia_ID = @_hiventHandle.getHivent().multimedia.substring(2)

    # generate content
    body = new HG.Div null, "hivent-body"

    titleDiv = new HG.Div null, "guiPopoverTitle"
    titleDiv.j().html @_hiventHandle.getHivent().name
    body.append titleDiv

    text = new HG.Div null, "hivent-content"

    description = @_hiventHandle.getHivent().description
    if description.length > @_description_length
      desc_output = description.substring(0,@_description_length)
      text.innerHTML = desc_output + "... "
    else
      text.innerHTML = description

    body.append text

    # ============================================================================

    locationString = ''
    if hiventIndex? and @_hiventHandle.getHivent().locationName?
      locationString = @_hiventHandle.getHivent().locationName[hiventIndex] + ', '

    date = document.createElement "span"
    date.className = "date"
    date.innerHTML = ' - ' + locationString + @_hiventHandle.getHivent().displayDate

    gotoDate = document.createElement "i"
    gotoDate.className = "fa fa-clock-o"
    $(gotoDate).tooltip {title: "Springe zum Ereignisdatum", placement: "right", container:"#histoglobe"}
    $(gotoDate).click () =>
      @_hgInstance.timeline.moveToDate @_hiventHandle.getHivent().startDate, 0.5
    date.appendChild gotoDate

    text.appendChild date

    # ============================================================================

    # if !showArrow
    #   container = window.body

    # create popover
    @_popover = new HG.Popover
      hgInstance: hgInstance
      hiventHandle: hiventHandle
      placement:  "top"
      content:    body.dom()
      title:      @_hiventHandle.getHivent().name
      container:  container
      showArrow:  showArrow
      fullscreen: !showArrow

    @_popover.onClose @, () =>
      @_hiventHandle.inActiveAll()

    @_hiventHandle.onDestruction @, @_popover.destroy


  # ============================================================================
  show: (position) =>
    @_popover.show
      x: position.at(0)
      y: position.at(1)
      @_visible = true
      @_hgInstance.hiventInfoAtTag?.setOption("event", @_hiventHandle._hivent.id)

  # ============================================================================
  hide: =>
    @_popover.hide()
    @_hiventHandle._activated = false
    @_visible = false
    @_hgInstance.hiventInfoAtTag?.unsetOption("event")

  # ============================================================================
  isVisible: =>
    @_visible

  # ============================================================================
  updatePosition: (position) ->
    @_popover.updatePosition

  # ============================================================================
  destroy: () ->
    @_popover.destroy()

