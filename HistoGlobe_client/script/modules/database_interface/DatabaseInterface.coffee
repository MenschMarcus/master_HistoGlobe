window.HG ?= {}

# ==============================================================================
# loads initial areas and hivents from the server and creates their links
# to each other via start/end hivents and ChangeAreas/ChangeAreaNames/Territorie
# ==============================================================================

class HG.DatabaseInterface


  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################


  # ============================================================================
  constructor: () ->
    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onFinishLoadingInitData'


  # ============================================================================
  hgInit: (@_hgInstance) ->

    # add to hg instance
    @_hgInstance.databaseInterface = @

    # include
    @_geometryReader = new HG.GeometryReader

    ### temporary quick and dirty solution ###

    $.ajax
      url:  'get_all/'
      type: 'POST'
      data: ""

      # success callback: load areas and hivents here and connect them
      success: (response) =>
        dataObj = $.parseJSON response

        # create Areas
        for areaData in dataObj.areas
          area = new HG.Area areaData.id
          areaHandle = new HG.AreaHandle @_hgInstance, area
          area.handle = areaHandle
          @_hgInstance.areaController.addAreaHandle areaHandle

        # create AreaNames and AreaTerritories and store them
        # so they can be linked to ChangeAreas later
        areaNames = []
        for anData in dataObj.area_names
          anData = @_areaNameToClient anData
          areaName = new HG.AreaName anData
          areaName.area = anData.area
          areaNames.push areaName

        areaTerritories = []
        for atData in dataObj.area_territories
          atData = @_areaTerritoryToClient atData
          areaTerritory = new HG.AreaTerritory atData
          areaTerritory.area = atData.area
          areaTerritories.push areaTerritory

        # keep track of earliest data to know where to start tracing the changes
        minDate = moment()

        # create Hivents
        for hData in dataObj.hivents
          hivent = new HG.Hivent @_hiventToClient hData
          minDate = moment.min(minDate, hivent.effectDate)

          # create HistoricalChanges
          for hcData in hData.historical_changes
            hcData = @_historicalChangeToClient hcData
            hcData = @_validateHistoricalChange hcData
            historicalChange = new HG.HistoricalChange  hcData.id
            historicalChange.operation =                hcData.operation
            historicalChange.hivent =                   hcData.hivent

            # create AreaChanges
            for acData in hcData.areaChanges
              acData = @_areaChangeToClient acData, areaNames, areaTerritories
              acData = @_validateAreaChange acData
              areaChange = new HG.AreaChange acData.id
              areaChange.operation =        acData.operation
              areaChange.historicalChange = historicalChange
              areaChange.area =             acData.area
              areaChange.oldAreaName =      acData.oldAreaName
              areaChange.newAreaName =      acData.newAreaName
              areaChange.oldAreaTerritory = acData.oldAreaTerritory
              areaChange.newAreaTerritory = acData.newAreaTerritory

              # link HistoricalChange <- ChangeArea
              historicalChange.areaChanges.push areaChange

              # link ChangeArea <- Area / AreaName / AreaTerritory
              switch areaChange.operation

                when 'ADD'
                  areaChange.area.startChange =             areaChange
                  areaChange.newAreaName.startChange =      areaChange
                  areaChange.newAreaTerritory.startChange = areaChange

                when 'DEL'
                  areaChange.area.endChange =               areaChange
                  areaChange.oldAreaName.endChange =        areaChange
                  areaChange.oldAreaTerritory.endChange =   areaChange

                when 'TCH'
                  areaChange.area.updateChanges.push        areaChange
                  areaChange.oldAreaTerritory.endChange =   areaChange
                  areaChange.newAreaTerritory.startChange = areaChange

                when 'NCH'
                  areaChange.area.updateChanges.push        areaChange
                  areaChange.oldAreaName.endChange =        areaChange
                  areaChange.newAreaName.startChange =      areaChange

              # link Hivent <- HistoricalChange
              hivent.historicalChanges.push historicalChange

          # finalize handle
          hiventHandle = new HG.HiventHandle @_hgInstance, hivent
          hivent.handle = hiventHandle
          @_hgInstance.hiventController.addHiventHandle hiventHandle

        # create territorial relations between areas
        for trData, idx in dataObj.territory_relation
          sovereignt = (@_hgInstance.areaController.getAreaHandle trData.sovereignt)?.getArea()
          dependency = (@_hgInstance.areaController.getAreaHandle trData.dependency)?.getArea()

          # link both areas
          sovereignt.dependencies.push dependency
          dependency.sovereignt = sovereignt

        # DONE!
        # hack: make min date slightly smaller to detect also first change
        newMinDate = minDate.clone()
        newMinDate.subtract 10, 'year'
        @notifyAll 'onFinishLoadingInitData', newMinDate

      error: @_errorCallback



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################


  # ============================================================================
  # data objects from the client to the server to each other
  # ============================================================================

  _areaTerritoryToServer: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      geometry:             dataObj.geometry.wkt()
      representative_point: dataObj.representativePoint.wkt()
      area:                 dataObj.area?.id
      start_change:         dataObj.startChange?.id
      end_change:           dataObj.endChange?.id
    }

  # ----------------------------------------------------------------------------
  _areaTerritoryToClient: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      geometry:             @_geometryReader.read dataObj.geometry
      representativePoint:  @_geometryReader.read dataObj.representative_point
      area:                 (@_hgInstance.areaController.getAreaHandle dataObj.area).getArea()
      startChange:          dataObj.start_change  # only id!
      endChange:            dataObj.end_change    # only id!
    }

  # ----------------------------------------------------------------------------
  _areaNameToServer: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      short_name:           dataObj.shortName
      formal_name:          dataObj.formalName
      area:                 dataObj.area?.id
      start_change:         dataObj.startChange?.id
      end_change:           dataObj.endChange?.id
    }

  # ----------------------------------------------------------------------------
  _areaNameToClient: (dataObj) ->
    {
      id:                   parseInt dataObj.id
      shortName:            dataObj.short_name
      formalName:           dataObj.formal_name
      area:                 (@_hgInstance.areaController.getAreaHandle dataObj.area).getArea()
      startChange:          dataObj.start_change  # only id!
      endChange:            dataObj.end_change    # only id!
    }

  # ----------------------------------------------------------------------------
  _hiventToClient: (dataObj) ->
    {
      id :                dataObj.id
      name :              dataObj.name
      startDate :         moment(dataObj.start_date)
      endDate :           moment(dataObj.end_date?)
      effectDate :        moment(dataObj.effect_date)
      secessionDate :     moment(dataObj.secession_date?)
      displayDate :       moment(dataObj.display_date?)
      locationName :      dataObj.location_name          ?= null
      locationPoint :     dataObj.location_point         ?= null
      locationArea :      dataObj.location_area          ?= null
      description :       dataObj.description            ?= null
      linkUrl :           dataObj.link_url               ?= null
      linkDate :          moment(dataObj.link_date?)
    }

  # ----------------------------------------------------------------------------
  _hiventToServer: (dataObj) ->
    # TODO if necessary

  # ----------------------------------------------------------------------------
  _historicalChangeToClient: (dataObj) ->
    {
      id:           parseInt dataObj.id
      operation:    dataObj.operation
      hivent:       dataObj.hivent
      areaChanges:  dataObj.area_changes  # not changed, yet
    }

  # ----------------------------------------------------------------------------
  _historicalChangeToServer: (dataObj) ->
    # TODO if necessary

  # ----------------------------------------------------------------------------
  _areaChangeToClient: (dataObj, areaNames, areaTerritories) ->
    {
      id:               parseInt dataObj.id
      operation:        dataObj.operation
      historicalChange: dataObj.historical_change # not changed, yet
      area:             (@_hgInstance.areaController.getAreaHandle dataObj.area)?.getArea()
      oldAreaName:      areaNames.filter (obj) -> obj.id is dataObj.old_area_name
      newAreaName:      areaNames.filter (obj) -> obj.id is dataObj.new_area_name
      oldAreaTerritory: areaTerritories.filter (obj) -> obj.id is dataObj.old_area_territory
      newAreaTerritory: areaTerritories.filter (obj) -> obj.id is dataObj.new_area_territory
    }

  # ----------------------------------------------------------------------------
  _areaChangeToServer: (dataObj) ->
    # TODO if necessary


  # ============================================================================
  # validation for all data in HistoricalChange
  # ensures that HistoricalChange can correctly be executed
  # ============================================================================

  _validateHistoricalChange: (dataObj) ->

    # check if id is a number
    if isNaN(dataObj.id)
      return console.error "The id is not valid"

    # check if operation type is correct
    if ['CRE','UNI','INC','SEP','SEC','NCH','TCH','DES'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

    # got all the way here? Then everything is good :)
    return dataObj


  # ============================================================================
  # validation for all data in AreaChange
  # ensures that AreaChange can correctly be executed
  # ============================================================================

  _validateAreaChange: (dataObj) ->

    # check if id is a number
    dataObj.id = parseInt dataObj.id
    if isNaN(dataObj.id)
      return console.error "The id is not valid"
    # check if operation type is correct
    if ['ADD','DEL','TCH','NCH'].indexOf(dataObj.operation) is -1
      return console.error "The operation type " + dataObj.operation + " is not valid"

    # check if area is given
    if not dataObj.area
      return console.error "The associated Area could not been found"

    # check if old/new area name/territories are singular
    if dataObj.oldAreaName.length is 0
      dataObj.oldAreaName = null
    else if dataObj.oldAreaName.length is 1
      dataObj.oldAreaName = dataObj.oldAreaName[0]
    else
      return console.error "There have been multiple AreaNames found, this is impossible"

    if dataObj.newAreaName.length is 0
      dataObj.newAreaName = null
    else if dataObj.newAreaName.length is 1
      dataObj.newAreaName = dataObj.newAreaName[0]
    else
      return console.error "There have been multiple AreaNames found, this is impossible"

    if dataObj.oldAreaTerritory.length is 0
      dataObj.oldAreaTerritory = null
    else if dataObj.oldAreaTerritory.length is 1
      dataObj.oldAreaTerritory = dataObj.oldAreaTerritory[0]
    else
      return console.error "There have been multiple AreaTerritorys found, this is impossible"

    if dataObj.newAreaTerritory.length is 0
      dataObj.newAreaTerritory = null
    else if dataObj.newAreaTerritory.length is 1
      dataObj.newAreaTerritory = dataObj.newAreaTerritory[0]
    else
      return console.error "There have been multiple AreaTerritorys found, this is impossible"

    # check if operation has necessary new/old area name/territory
    switch dataObj.operation

      when 'ADD'
        if not (
            (dataObj.newAreaName)           and
            (dataObj.newAreaTerritory)      and
            (not dataObj.oldAreaName)       and
            (not dataObj.oldAreaTerritory)
          )
          return console.error "The ADD operation does not have the expected data provided"

      when 'DEL'
        if not (
            (not dataObj.newAreaName)       and
            (not dataObj.newAreaTerritory)  and
            (dataObj.oldAreaName)           and
            (dataObj.oldAreaTerritory)
          )
          return console.error "The DEL operation does not have the expected data provided"

      when 'TCH'
        if not (
            (not dataObj.newAreaName)       and
            (dataObj.newAreaTerritory)      and
            (not dataObj.oldAreaName)       and
            (dataObj.oldAreaTerritory)
          )
          return console.error "The TCH operation does not have the expected data provided"

      when 'NCH'
        if not (
            (dataObj.newAreaName)           and
            (not dataObj.newAreaTerritory)  and
            (dataObj.oldAreaName)           and
            (not dataObj.oldAreaTerritory)
          )
          return console.error "The NCH operation does not have the expected data provided"

    # got all the way here? Then everything is good :)
    return dataObj























'''
### the sophisticated version goes here this afternoon
    # --------------------------------------------------------------------------
    # loading mechanism:
    # 1) load initial area ids and create their AreaHandles
    # ->  2) load initially visible area data and create their Name/Territory
    #     ->  3) load rest visible area data and create rest Names/Territories/Hivents
    #         ->  4) load rest data (invisible areas and rest hivents)
    # --------------------------------------------------------------------------

    @_hgInstance.onAllModulesLoaded @, () =>

      # includes
      @_geometryReader = new HG.GeometryReader
      @_areaController = @_hgInstance.areaController
      @_hiventController = @_hgInstance.hiventController

    # --------------------------------------------------------------------------
    # 1) load initial area and hivent ids () ->
    #    (all areas            {id, start hivent it, end hivent id},
    #     -> current name      {id, start hivent id, end hivent id},
    #     -> current territory {id, start hivent id, end hivent id},
    #     all hivents          {id})
    #   => create Area and AreaHandle
    #   => create Hivent and HiventHandle
    # --------------------------------------------------------------------------
      @_loadInitAreaIds()

    # --------------------------------------------------------------------------
    # MAIN LOAD TO SEE INITIAL AREAS => as fast as possible
    # --------------------------------------------------------------------------
    # 2) load init visible area data ([area id, name id, territory id], [hivent id]) ->
    #    (visible area    (id),
    #     init name       (id, short name, formal name),
    #     init territory  (id, geometry, repr point))
    #   => get AreaHandle(area id)
    #   => create AreaName(init name)
    #   => create AreaTerritory (init territory)
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # 3) load rest visible area data ([area id, name id, territory id], [hivent id])
    #    (visible area      (id, predecessors, successors, sovereignt, dependencies),
    #     rest names       [(id, short name, formal name, start hivent, end hivent)],
    #     rest territories [(id, geometry, repr point, start hivent, end hivent)],
    #     hivents          [(id, ...full data...)])
    #   => get AreaHandle(area id)
    #     => update Area(predecessors, successors, sovereignt, dependencies)
    #     => create AreaNames(rest names)
    #     => create AreaTerritories(rest territories)
    #   => get HiventHandle
    #     => update Hivent
    #     => link start / end hivents of Area <-> Hivent->Change->ChangeArea
    #       (same for AreaName and AreaTerritory)
    # --------------------------------------------------------------------------

    # --------------------------------------------------------------------------
    # 4) load full invisible area data ([area id], [exisiting hivent id])
    #    (invisible area    (id, predecessors, successors, sovereignt, dependencies) +
    #     all names        [(id, short name, formal name, start hivent, end hivent)] +
    #     all territories  [(id, geometry, repr point, start hivent, end hivent)] +
    #     all rest hivents [(id, ...full data...)])
    #   => get AreaHandle(area id)
    #     => update Area(predecessors, successors, sovereignt, dependencies)
    #     => create AreaNames(rest names)
    #     => create AreaTerritories(rest territories)
    #   => get HiventHandle
    #     => link start / end hivents of Area <-> Hivent->Change->ChangeArea
    #       (same for AreaName and AreaTerritory)
    # --------------------------------------------------------------------------





  # ============================================================================
  # get initial set of information about area from the server:
  # id, start and endHivent and territorial relation
  # no name and geometry yet (to load fast which areas will eventually be there)
  # ============================================================================

  loadAllAreaIds: (@_hgInstance) ->

    request = {
      date: moment(@_hgInstance.timeController.getNowDate()).format()
    }

    $.ajax
      url:  'get_init_area_ids/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        console.log dataObj

        # create an area with id for each feature
        areaHandles = []
        $.each dataObj, (key, val) =>
          # create Area only with id
          area = new HG.Area val.id

          # create AreaHandle that is handed through the application
          areaHandle = new HG.AreaHandle @_hgInstance area

          # little hack: set temporary loading variables that will be replaced later
          areaHandle.tempLoadVars = {
            visible:      val.visible
            predecessors: val.predecessors
            successors:   val.successors
            sovereignt:   val.sovereignt
            dependencies: val.dependencies
          }
          areaHandles.push areaHandles

          # load Hivents in HiventController
          @notifyAll 'onLoadAreaHivents', val.start_hivent, val.end_hivent, areaHandle

        # load Areas completely in AreaController
        @notifyAll 'onFinishLoadingAreaIds', areaHandles


      # error callback: print error message
      error: @_errorCallback
  # load all areas that are initially (in)visible from the server
  # ============================================================================

  loadVisibleAreas: (visibleAreas) ->
    @_loadInitAreas @_getRequest visibleAreas, 'onLoadVisibleArea', 'onFinishLoadingVisibleAreas'

  # ----------------------------------------------------------------------------
  loadInvisibleAreas: (invisibleAreas) ->
    @_loadInitAreas @_getRequest invisibleAreas, 'onLoadInvisibleArea', 'onFinishLoadingInvisibleAreas'


  # ============================================================================
  convertToServerModel: (area) ->
    @_prepareAreaClientToServer area



  # ============================================================================
  # compile request header for initial area loading
  # ============================================================================

  _getRequest: (areaIds, areaLoadCallback, finishCallback) ->

    request = {
      areaIds:            areaIds
      centerLat:          @_hgInstance.map.getCenter()[0]
      centerLng:          @_hgInstance.map.getCenter()[1]
      chunkId:            0  # initial value
      chunkSize:          HGConfig.area_loading_chunk_size.val
      areaLoadCallback:   areaLoadCallback
      finishCallback:     finishCallback
    }


  # ============================================================================
  # recursively load all initially active areas from the server
  # ============================================================================

  _loadInitAreas: (request) ->

    $.ajax
      url:  'get_init_areas/'
      type: 'POST'
      data: JSON.stringify request

      # success callback: load areas here
      success: (response) =>

        # deserialize string to object
        dataObj = $.parseJSON response

        # update area properties for each loaded area
        $.each dataObj.features, (key, val) =>
          areaData = @_prepareAreaServerToClient val
          area = @_hgInstance.areaController.getArea areaData.id

          area.setGeometry areaData.geometry
          area.setRepresentativePoint areaData.representativePoint
          area.setShortName areaData.shortName
          area.setFormalName areaData.formalName
          area.setSovereigntyStatus areaData.sovereigntyStatus
          area.setTerritoryOf areaData.territoryOf

          @notifyAll request.areaLoadCallback, area


    # # get list of all associated names and their creation date
    # current_name = None
    # for name in AreaName.objects.filter(area=self):

    #   # get start and end date of the name
    #   start_date = name.start_change.hivent.effect_date
    #   try:
    #     end_date = name.end_change.hivent.effect_date
    #   except:
    #     end_date = timezone.now()

    #   # pick the 1 name that is inside the start and end date
    #   if (start_date <= request_date) and (request_date < end_date):
    #     current_name = name
    #     break



    # error handling: id and name must be given
    return null if (not hiventFromServer.id) or (not hiventFromServer.name)

    hiventData = {
      id :                hiventFromServer.id
      name :              hiventFromServer.name
      startDate :         moment(hiventFromServer.start_date)
      endDate :           moment(hiventFromServer.end_date?)
      effectDate :        moment(hiventFromServer.effect_date)
      secessionDate :     moment(hiventFromServer.secession_date?)
      displayDate :       moment(hiventFromServer.display_date?)
      locationName :      hiventFromServer.location_name          ?= null
      locationPoint :     hiventFromServer.location_point         ?= null
      locationArea :      hiventFromServer.location_area          ?= null
      description :       hiventFromServer.description            ?= null
      linkUrl :           hiventFromServer.link_url               ?= null
      linkDate :          moment(hiventFromServer.link_date?)
      changes :           []
    }

    # prepare changes
    for change in hiventFromServer.changes
      changeData = {
        operation:  change.operation
        oldAreas:   []
        newAreas:   []
      }
      # create unique array (each area is only once in the old/newArea array)
      for area in change.change_areas
        changeData.oldAreas.push area.old_area if (area.old_area?) and (changeData.oldAreas.indexOf(area.old_area) is -1)
        changeData.newAreas.push area.new_area if (area.new_area?) and (changeData.newAreas.indexOf(area.new_area) is -1)
      # add change to hivent
      hiventData.changes.push changeData

    return hiventData

  # ============================================================================
  # _prepareHiventClientToServer: (hiventFromServer) ->


  _errorCallback: (xhr, errmsg, err) =>
    console.log xhr
    console.log errmsg, err
    console.log xhr.responseText

  # ============================================================================
  # TODO:
  # allow multiple locations per hivent
  # data.location = data.location?.replace(/\s*;\s*/g, ';').split(';')
  # data.lat = "#{data.lat}".replace(/\s*;\s*/g, ';').split(';') if data.lat?
  # data.lng = "#{data.lng}".replace(/\s*;\s*/g, ';').split(';') if data.lng?
'''