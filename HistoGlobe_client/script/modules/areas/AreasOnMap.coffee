window.HG ?= {}

class HG.AreasOnMap

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->

  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add areasOnMap to HG instance
    @_hgInstance.areasOnMap = @

    # error handling
    if not @_hgInstance.areaController
      console.error "Unable to show areas on the map: AreaController module not detected in HistoGlobe instance!"

    # init variables
    @_map = @_hgInstance.map.getMap()
    @_zoomLevel = @_map.getZoom()
    @_selectedAreas = []

    # includes
    @_labelManager = new HG.LabelManager @_map

    # event handling
    @_hgInstance.onAllModulesLoaded @, () =>

      # listen to geometry changes from area controller
      @_hgInstance.areaController.onCreateGeometry @, (area) =>
        @_createGeometry area

      @_hgInstance.areaController.onUpdateGeometry @, (area) =>
        @_updateGeometry area

      @_hgInstance.areaController.onRemoveGeometry @, (area) =>
        @_removeGeometry area

      # listen to name changes from area controller
      @_hgInstance.areaController.onCreateName @, (area) =>
        @_createLabel area

      @_hgInstance.areaController.onUpdateName @, (area) =>
        @_updateLabel area

      @_hgInstance.areaController.onUpdateRepresentativePoint @, (area) =>
        @_updateLabelPosition area

      @_hgInstance.areaController.onRemoveName @, (area) =>
        @_removeLabel area

      # listen to status updates from area controller
      @_hgInstance.areaController.onUpdateStatus @, (area) =>
        @_updateProperties area

      @_hgInstance.areaController.onSelect @, (area) =>
        @_select area

      @_hgInstance.areaController.onToggleSelect @, (oldArea, newArea) =>
        @_deselect oldArea
        @_select newArea

      @_hgInstance.areaController.onDeselect @, (area) =>
        @_deselect area


      # listen to zoom event from map
      @_map.on "zoomend", @_onZoom



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  ### AREA VISUALIZATION ###

  # ============================================================================
  # add leaflet layers to the map
  # (separation for geometry = MultiPolygon and name = Label)

  # ----------------------------------------------------------------------------
  _createGeometry: (area) ->

    # styling area in CSS based on its calss is a bad idea,
    # because d3 can not update that => use leaflet layer options
    # initial options (including style properties)
    # to have them ready for being changied in d3
    properties = area.getStyle()
    options = {
      'className':    'area'
      'clickable':    true
      'fillColor':    properties.areaColor
      'fillOpacity':  properties.areaOpacity
      'color':        properties.borderColor
      'opacity':      properties.borderOpacity
      'weight':       properties.borderWidth
    }

    area.geomLayer = new L.multiPolygon area.getGeometry().latLng(), options

    # interaction
    area.geomLayer.on 'mouseover', @_onFocus
    area.geomLayer.on 'mouseout', @_onUnfocus
    area.geomLayer.on 'click', @_onClick

    # create double-link: leaflet layer knows HG area and HG area knows leaflet layer
    area.geomLayer.hgArea = area
    area.geomLayer.addTo @_map


  # ----------------------------------------------------------------------------
  _createLabel: (area) ->

    # create label with name and position
    area.labelLayer = new L.Label()
    area.labelLayer.setContent area.getShortName()
    area.labelLayer.setLatLng area.getRepresentativePoint().latLng()

    # priority of the label = its area
    area.labelLayer.priority = Math.round(area.getGeometry().getArea()*1000)

    # add to LabelManager
    @_labelManager.insert area.labelLayer

    # create double-link: leaflet label knows HG area and HG area knows leaflet label
    area.labelLayer.hgArea = area

  # ============================================================================
  # change leaflet layers on the map

  # ----------------------------------------------------------------------------
  _updateGeometry: (area) ->
    area.geomLayer.setLatLngs area.getGeometry().latLng()
    # TODO: necessary?
    area.geomLayer.hgArea = area

  # ----------------------------------------------------------------------------
  _updateLabel: (area) ->
    area.labelLayer.setContent area.getShortName()
    @_labelManager.update area.labelLayer

  # ----------------------------------------------------------------------------
  _updateLabelPosition: (area) ->
    area.labelLayer.setLatLng area.getRepresentativePoint().latLng()

    # recenter text
    area.labelLayer.options.offset = [
      -(area.labelLayer._container.offsetWidth/2),
      -(area.labelLayer._container.offsetHeight/2)
    ]
    area.labelLayer._updatePosition()

  # ----------------------------------------------------------------------------
  _updateProperties: (area) ->
    properties = area.getStyle()
    @_animate area.geomLayer, {
      'fill':           properties.areaColor
      'fill-opacity':   properties.areaOpacity
      'stroke':         properties.borderColor
      'stroke-opacity': properties.borderOpacity
      'stroke-width':   properties.borderWidth
    }, HGConfig.slow_animation_time.val


  # ============================================================================
  # remove leaflet layers from map

  _removeGeometry: (area) ->
    # remove double-link: leaflet layer from area and area from leaflet layer
    @_map.removeLayer area.geomLayer
    area.geomLayer = null

  # ----------------------------------------------------------------------------
  _removeLabel: (area) ->
    # remove double-link: leaflet layer from area and area from leaflet layer
    @_labelManager.remove area.labelLayer
    area.labelLayer = null


  ### EVENT HANDLING ###

  # ============================================================================
  # areas

  # ----------------------------------------------------------------------------
  _onFocus: (evt) =>
    @_hgInstance.areaController.focusArea (evt.target.hgArea)

  # ----------------------------------------------------------------------------
  _onUnfocus: (evt) =>
    @_hgInstance.areaController.unfocusArea (evt.target.hgArea)

  # ----------------------------------------------------------------------------
  _onClick: (evt) =>
    @_hgInstance.areaController.selectArea (evt.target.hgArea)
    # bug: after clicking, it is assumed to be still focused
    # fix: unfocus afterwards
    @_onUnfocus evt

  # ----------------------------------------------------------------------------
  _select: (area) =>
    # accumulate fullBound box around all currently selected areas
    fullBound = area.geomLayer.getBounds() # L.latLngBounds
    for selArea in @_selectedAreas
      currBound = selArea.geomLayer.getBounds()
      fullBound._northEast.lat = Math.max(currBound.getNorth(), fullBound.getNorth())
      fullBound._northEast.lng = Math.max(currBound.getEast(),  fullBound.getEast())
      fullBound._southWest.lat = Math.min(currBound.getSouth(), fullBound.getSouth())
      fullBound._southWest.lng = Math.min(currBound.getWest(),  fullBound.getWest())
    @_map.fitBounds fullBound
    # add area to list in last step
    @_selectedAreas.push area

  # ----------------------------------------------------------------------------
  _deselect: (area) =>
    idx = @_selectedAreas.indexOf area
    @_selectedAreas.splice idx, 1
    # focus back to remaining selected areas
    if @_selectedAreas.length > 0
      fullBound = @_selectedAreas[0].geomLayer.getBounds() # L.latLngBounds
      for selArea in @_selectedAreas
        currBound = selArea.geomLayer.getBounds()
        fullBound._northEast.lat = Math.max(currBound.getNorth(), fullBound.getNorth())
        fullBound._northEast.lng = Math.max(currBound.getEast(),  fullBound.getEast())
        fullBound._southWest.lat = Math.min(currBound.getSouth(), fullBound.getSouth())
        fullBound._southWest.lng = Math.min(currBound.getWest(),  fullBound.getWest())
      @_map.fitBounds fullBound

  # ============================================================================
  # map

  # ----------------------------------------------------------------------------
  _onZoom: (evt) =>
    # get zoom direction
    oldZoom = @_zoomLevel
    newZoom = @_map.getZoom()

    # check zoom direction and update labels
    if newZoom > oldZoom # zoom in
      @_labelManager.zoomIn()
    else
      @_labelManager.zoomOut()

    # update zoom level
    @_zoomLevel = newZoom

  # ============================================================================
  ### HELPER FUNCTIONS ###

  # ============================================================================
  _addLinebreaks : (name) =>
    # 1st approach: break at all whitespaces and dashed lines
    name = name.replace /\s/gi, '<br\>'
    name = name.replace /\-/gi, '-<br\>'

    # # find all whitespaces in the name
    # len = name.length
    # regEx = /\s/gi  # finds all whitespaces (\s) globally (g) and case-insensitive (i)
    # posWhite = []
    # while result = regEx.exec name
    #   posWhite.push result.index
    # for posW in posWhite

    name

  # ============================================================================
  # actual animation, N.B. needs animation duration as a parameter !!!
  _animate: (area, attributes, duration, finishFunction) ->
    console.error "no animation duration given" if not duration?
    if area._layers?
      for id, path of area._layers
        d3.select(path._path).transition().duration(duration).attr(attributes).each('end', finishFunction)
    else if area._path?
      d3.select(area._path).transition().duration(duration).attr(attributes).each('end', finishFunction)