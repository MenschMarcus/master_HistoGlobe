window.HG ?= {}

# ==============================================================================
# This is HistoGlobe's central class. It initiates module loading and can be
# used to store/gather information on the current state of the application.
# ==============================================================================
class HG.HistoGlobe

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  # Class constructor
  # A module configuration file located at "pathToJson" is parsed and evaluated,
  # i.e., all specified modules are constructed and initialized.
  # ============================================================================
  constructor: (pathToJson) ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    # Callback specification
    # Any object may listen for notifictations on any of the below signals.
    @addCallback 'onAllModulesLoaded'
    @addCallback 'onWindowResize'

    # issue: HGConfig provides rose variables, but for colors it does not return
    # the hex code '#rrggbb', but an object with r, g, b, a and val attributes
    # the val attribute is a rather weird number string
    # solution: for colors, rewrite this number string to the actual hex value
    for prop, val of HGConfig
      # decide if color value or not
      if val.r? and val.g? and val.b?
        # calculate color value in hex
        r = @_toHex val.r
        g = @_toHex val.g
        b = @_toHex val.b
        # rewrite properties
        val.type = 'color'
        val.val = '#'+r+g+b

    # Asynchronous loading of a file containing module information located at
    # "pathToJson". Result is stored in the "config" object and passed to the
    # specified callback function.
    $.getJSON(pathToJson, (config) =>

      # Config of the central HistoGlobe instance is loaded. $.extend is used to
      # combine the default and the actual config. Thus, all attributes
      # specified in "defaultConfig" are stored in "@config" and either being
      # overridden by the loaded config or kept as default.
      defaultConfig =
        nowYear: 2014
        minYear: 1940
        maxYear: 2020
        startPoint: [51.505, 10.09]   # Weimar
        configPath:   '../HistoGlobe_client/config/'
        graphicsPath: 'common/graphics/'
        tiles:        'common/tiles/normal'
        tilesHC:      'common/tiles/high_contrast'

      @config = $.extend {}, defaultConfig, config["HistoGlobe"]

      # override paths
      @config.graphicsPath =  @config.configPath + @config.graphicsPath
      @config.tiles =         @config.configPath + @config.tiles
      @config.tilesHC =       @config.configPath + @config.tilesHC

      ### SETUP GUI ###

      @config.container = new HG.Div 'histoglobe'
      document.body.appendChild @config.container.dom()  if document.body != null

      @_topArea = new HG.Div 'top-area'
      @config.container.appendChild @_topArea

      @_spatialArea = new HG.Div 'spatial-area'
      @_topArea.appendChild @_spatialArea

      @_spatialCanvas = new HG.Div 'spatial-canvas'
      @_spatialArea.appendChild @_spatialCanvas


      # Auxiliary function for module loading. Tries to create an object by the
      # name of "moduleName", passing "moduleConfig" to the object's constructor.
      # If the creation was successful, "hgInit" is called on the new module.
      load_module = (moduleName, moduleConfig) =>

        # error handling: ignore comment modules:
        # "### COMMENT ###"
        return if moduleName.startsWith('#') and moduleName.endsWith('#')

        defaultConf =
          enabled : true

        moduleConfig = $.extend {}, defaultConf, moduleConfig

        # Check if there exists a module by the specified name. To ensure custom
        # modules they must be added them to the HG scope
        # usage: class HG.ModuleName
        if window["HG"][moduleName]?
          # Only load modules which are enabled
          if moduleConfig.enabled
            newMod = new window["HG"][moduleName] moduleConfig
            @addModule newMod
        else
          console.error "The module #{moduleName} is not part of the HG namespace!"

      # Load all modules specified in the configuration file.
      for moduleName, moduleConfig of config
        '''if moduleName is "Widgets"
          for widget in moduleConfig
            load_module widget.type, widget
        else if moduleName isnt "HistoGlobe"'''
        if moduleName isnt "HistoGlobe"
          load_module moduleName, moduleConfig

        window.hgConf=config

      # After all modules are loaded, notify whoever is interested
      @notifyAll "onAllModulesLoaded"

      # resize event handling
      $(window).on 'resize', @_onResize
      @_updateLayout()
    )


  # ============================================================================
  # Calls "hgInit" on the object "module". A reference to the HistoGlobe
  # instance. Thus, modules may interact with and/or save a reference to the
  # HistoGlobe instance within hgInit.
  # ============================================================================
  addModule: (module) ->
    module.hgInit @

  # ============================================================================
  # Checks whether or not the application is running in mobile mode.
  # ============================================================================
  isInMobileMode: =>
    window.innerWidth < HGConfig.map_min_width.val

  # ============================================================================
  # Returns the DOM element containing all HistoGlobe visuals
  # ============================================================================
  getContainer: () ->     @config.container
  getTopArea: () ->       @_topArea
  getSpatialCanvas: () -> @_spatialCanvas

  # ============================================================================
  # Getter for information on time boundaries/the visualization's start year.
  # ============================================================================
  getMinMaxYear: () ->
    [@config.minYear, @config.maxYear]

  getStartYear: () ->
    @config.nowYear

  # ============================================================================
  # Getter for effective size of spatial canvas (map/globe)
  # ============================================================================
  getSpatialCanvasSize: () ->
    return {
      x: window.innerWidth
      y: @_top_area.j().outerHeight()
    }


  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _onResize: () =>
    @_updateLayout()

  # ============================================================================
  _updateLayout: =>
    width = window.innerWidth
    height = window.innerHeight - @_topArea.j().offset().top

    map_height = height - HGConfig.timeline_height.val
    map_width = width

    @_spatialArea.dom().style.width = "#{map_width}px"
    @_spatialArea.dom().style.height = "#{map_height}px"

    @notifyAll 'onWindowResize', map_width, map_height

  # ============================================================================
  _toHex: (prop) ->
    v = prop.toString 16
    v = "0"+v if v.length is 1
    v