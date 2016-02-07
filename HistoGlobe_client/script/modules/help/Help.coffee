window.HG ?= {}

class HG.Help

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      autoShow: false
      elements: []

    @_config = $.extend {}, defaultConfig, config

    @_div = new HG.Div null, "help-overlay"

    @_div.dom().click () =>
      @hide()
      window.setTimeout () =>
        $(@_button).attr('title', "Hilfe wieder einblenden").tooltip('fixTitle').tooltip('show');
        window.setTimeout () =>
          $(@_button).attr('title', "Hilfe einblenden").tooltip('fixTitle').tooltip('hide');
        , 2000
      , 500


    @_div.dom().fadeOut 0

    for e in @_config.elements
      @addHelp e

  # ============================================================================
  hgInit: (@_hgInstance) ->
    @_hgInstance.help = @

    @_hgInstance.getContainer().appendChild @_div.obj()

    if @_config.autoShow
      @_hgInstance.onAllModulesLoaded @, () =>
        hgInstance.hiventInfoAtTag?.onHashChanged @, (key, value) =>
          if key is "help" and value is "true"
            @show()
            hgInstance.hiventInfoAtTag?.unsetOption("help")

    if hgInstance.controlButtons?

      help =
        icon: "fa-question"
        tooltip: "Hilfe einblenden"
        callback: () =>
          unless @_hgInstance._collapsed
            @_hgInstance._collapse()
          @show()

      @_button = hgInstance.controlButtons.addButton help

  # ============================================================================
  show:() ->
    @_div.dom().fadeIn()

  # ============================================================================
  hide:() ->
    @_div.dom().fadeOut()

  # ============================================================================
  addHelp:(element) ->
    image = new HG.Img null, 'help-image', element.image
    @_div.append image

    image.dom().load () =>
      image.dom().css {"max-width": image.naturalWidth + "px"}
      image.dom().css {"width": element.width}

    if element.anchorX is "left"
      image.dom().css {"left":element.offsetX + "px"}
    else if element.anchorX is "right"
      image.dom().css {"right":element.offsetX + "px"}
    else if element.anchorX is "center"
      image.dom().css {"left": element.offsetX + "px", "right": 0, "margin-right": "auto", "margin-left": "auto"}

    if element.anchorY is "top"
      image.dom().css {"top":element.offsetY + "px"}
    else if element.anchorY is "bottom"
      image.dom().css {"bottom":element.offsetY + "px"}
    else if element.anchorY is "center"
      image.dom().css {"top": element.offsetY + "px", "bottom": 0, "margin-bottom": "auto", "margin-top": "auto"}



