window.HG ?= {}

class HG.NewHiventBox

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (@_hgInstance, @_stepData, @_operationDescription) ->

    # handle callbacks
    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback 'onReady'
    @addCallback 'onUnready'

    ### SETUP UI ###

    @_hiventBox = new HG.Div 'new-hivent-box', null
    @_hgInstance.getTopArea().appendChild @_hiventBox

    ## 1) choose between select existing and create new hivent
    @_makeDecisionStep()

    ## 2.1) select existing hivent
    @_hgInstance.buttons.existingHiventSearch.onClick @, () ->
      # TODO: write id into out data and be ready :-)

    ## 2.2) create new hivent
    @_hgInstance.buttons.newHiventInBox.onClick @, () ->
      # cleanup box and repupulate with new form
      @_hiventBox.j().empty()
      @_makeNewHiventForm()


  # ============================================================================
  destroy: () ->
    @_hiventBox.remove()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # decision: select existing hivent OR create new one?
  _makeDecisionStep: () ->

    ## option A) select existing hivent

    selectExistingWrapper = new HG.Div null, ['new-hivent-box-selection-wrapper']
    @_hiventBox.appendChild selectExistingWrapper

    selectExistingText = new HG.Div null, ['new-hivent-box-text']
    selectExistingText.j().html "Select Existing Historical Event"
    selectExistingWrapper.appendChild selectExistingText

    searchBox = new HG.TextInput @_hgInstance, 'selectExitingHivent', ['new-hivent-input']
    searchBox.setPlaceholder "find existing hivent by name, date, location, ..."
    selectExistingWrapper.appendChild searchBox

    searchIcon = new HG.Button @_hgInstance,
      'existingHiventSearch', ['button-no-background'],
      [
        {
          'id':         'normal',
          'iconFA':     'search'
          'callback':   'onClick'
        }
      ]
    selectExistingWrapper.appendChild searchIcon.dom()


    ## OR
    orHalf = new HG.Div null, ['new-hivent-box-selection-center', 'new-hivent-box-text']
    orHalf.j().html "OR"
    @_hiventBox.appendChild orHalf


    ## option B) create new hivent

    createNewHiventWrapper = new HG.Div 'create-new-hivent', ['new-hivent-box-selection-wrapper']
    @_hiventBox.appendChild createNewHiventWrapper

    newHiventButton = new HG.Button @_hgInstance,
      'newHiventInBox', ['tooltip-bottom'],
      [
        {
          'id':       'normal',
          'tooltip':  "Create New Hivent",
          'iconOwn':  @_hgInstance.config.graphicsPath + 'buttons/new_hivent.svg',
          'callback': 'onClick'
        }
      ]
    createNewHiventWrapper.appendChild newHiventButton.dom()

    createNewHiventText = new HG.Div null, ['new-hivent-box-text']
    createNewHiventText.j().html "create new Historical Event"
    createNewHiventWrapper.appendChild createNewHiventText


  # ============================================================================
  # forms with Hivent information
  _makeNewHiventForm: () ->

    ### SETUP UI ###

    formWrapper = new HG.Div 'new-hivent-info-wrapper', ['new-hivent-box-selection-wrapper']
    @_hiventBox.appendChild formWrapper

    ## name
    hiventName = new HG.TextInput @_hgInstance, 'newHiventName', ['new-hivent-information']
    hiventName.setPlaceholder "Name of the Historical Event"
    formWrapper.appendChild hiventName.dom()

    ## date
    hiventDate = new HG.TextInput @_hgInstance, 'newHiventDate', ['new-hivent-information']
    hiventDate.setValue @_hgInstance.timeline.getNowDate().toLocaleDateString()
    formWrapper.appendChild hiventDate.dom()

    ## location
    # TODO: create marker on the map, get GPS coordinates from it
    # TODO: detect location name and put marker on the map
    hiventLocation = new HG.TextInput @_hgInstance, 'newHiventLocation', ['new-hivent-information']
    hiventLocation.setPlaceholder "Location (optional)"
    formWrapper.appendChild hiventLocation.dom()

    ## description
    hiventDescription = new HG.TextInputArea @_hgInstance, 'newHiventDescription', ['new-hivent-information'], [null, 5]
    hiventDescription.setPlaceholder "Description of the Hivent (take your space...)"
    formWrapper.appendChild hiventDescription.dom()

    ## link
    # TODO: style nicely
    hiventLink = new HG.TextInput @_hgInstance, 'newHiventLink', ['new-hivent-information']
    hiventLink.setPlaceholder "Link to wikipedia article"
    formWrapper.appendChild hiventLink.dom()

    ## changes
    # TODO: put in information about current change
    # TODO: connect this with hg action language
    hiventChanges = new HG.Div 'newHiventChanges', ['new-hivent-information']
    hiventChanges.j().html @_operationDescription
    formWrapper.appendChild hiventChanges.dom()


    ## buttons
    # TODO: are the buttons really necessary or can't I reuse the buttons from the workflow window?
    # is against "direct manipulation" paradigm, but kind of makes sense
    # -> no! I should include them
    # abortButton = new HG.Button @_hgInstance,
        # 'addChangeAbort', ['button-abort'],
    #   [
    #     {
    #       'iconFA':   'times'
    #       'callback': 'onClick'
    #     }
    #   ]
    # formWrapper.appendChild abortButton.dom()

    # okButton = new HG.Button @_hgInstance,
        # 'addChangeOK', null,
    #   [
    #     {
    #       'iconFA':   'check'
    #       'callback': 'onClick'
    #     }
    #   ]
    # formWrapper.appendChild okButton.dom()


    ### INTERACTION ###

    ## name done => ready to submit
    hiventName.onChange @, (name) ->
      # save to data
      @_stepData.outData.hiventInfo.name = name
      # tell everyone: "I am done"
      if name isnt ''
        @notifyAll 'onReady'
      else
        @notifyAll 'onUnready'

    ## synchronize hivent date with timeline
    # timeline -> hivent box
    @_hgInstance.timeline.onNowChanged @, (date) ->
      nowDate = moment(date).format()
      hiventDate.setValue nowDate
      @_stepData.outData.hiventInfo.start_date = nowDate

    # timeline <- hivent box
    hiventDate.onChange @, (dateString) ->
      formats = [
        moment.ISO_8601,
        "DD.MM.YYYY",
        "DD/MM/YYYY",
        "YYYY"
      ]
      if moment(dateString, formats, true).isValid()
        @_hgInstance.timeline.setNowDate moment(dateString).toDate()
        @_stepData.outData.hiventInfo.start_date = moment(dateString).format()

    # hack: it is possible to finish this step without changing the date
    # => date has to be initially written into output
    @_stepData.outData.hiventInfo.start_date = moment(@_hgInstance.timeline.getNowDate()).format()

    ## convert location to lat/lng coordinates
    # TODO: geocoding
    hiventLocation.onChange @, (location) ->
      @_stepData.outData.hiventInfo.location_name = location

    ## save the description
    hiventDescription.onChange @, (description) ->
      @_stepData.outData.hiventInfo.description = description

    ## save the link
    hiventLink.onChange @, (link) ->
      @_stepData.outData.hiventInfo.link_url = link