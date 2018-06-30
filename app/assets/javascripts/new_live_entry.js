(function ($) {

    /**
     * UI object for the live event view
     *
     */
    var liveEntry = {


        /**
         * Stores the ID for the current event_group
         * this is pulled from the url and dumped on the page
         * then stored in this variable
         *
         * @type integer
         */
        currentEventGroupId: null,
        serverURI: null,
        currentEffortData: {}, // Remove
        lastEffortRequest: {}, // Remove
        eventGroupResponse: null,
        lastReportedSplitId: null,
        lastReportedBitkey: null,
        currentStationIndex: null,

        getEventLiveEntryData: function () {
            return $.get('/api/v1/event_groups/' + liveEntry.currentEventGroupId + '?include=events.efforts&fields[efforts]=bibNumber,eventId,fullName')
                .then(function (response) {
                    liveEntry.dataSetup.init(response);
                    liveEntry.timeRowsCache.init();
                    liveEntry.header.init();
                    liveEntry.liveEntryForm.init();
                    liveEntry.timeRowsTable.init();
                    liveEntry.pusher.init();
                });
        },

        splitsAttributes: function () {
            return liveEntry.eventGroupAttributes.ungroupedSplitAttributes
        },

        eventIdFromBib: function (bibNumber) {
            if (typeof liveEntry.bibEventMap !== 'undefined' && bibNumber !== '') {
                return liveEntry.bibEventMap[bibNumber]
            } else {
                return null
            }
        },

        getSplitId: function (eventId, splitIndex) {
            var id = String(eventId);
            return liveEntry.splitsAttributes()[splitIndex].entries[0].eventSplitIds[id]
        },

        bibStatus: function (rowObject) {
            var bibSubmitted = rowObject.bibNumber;
            var bibFound = rowObject.effortId;
            var splitFound = rowObject.splitId;

            if (!bibSubmitted) {
                return null
            } else if (!bibFound) {
                return 'bad'
            } else if (!splitFound) {
                return 'questionable'
            } else {
                return 'good'
            }
        },

        includedResources: function (resourceType) {
            return liveEntry.eventGroupResponse.included
                .filter(function (current) {
                    return current.type === resourceType;
                })
        },

        containsSubSplitKind: function (entries, subSplitKind) {
            return entries.reduce(function (p, c) {
                return p || c.subSplitKind === subSplitKind
            }, false)
        },

        /**
         * This kicks off the full UI
         *
         */
        init: function () {
            // Sets the currentEventGroupId once
            var $div = $('#js-event-group-id');
            liveEntry.currentEventGroupId = $div.data('event-group-id');
            liveEntry.serverURI = $div.data('server-uri');
            liveEntry.getEventLiveEntryData();
            liveEntry.importLiveWarning = $('#js-import-live-warning').hide().detach();
            liveEntry.importLiveError = $('#js-import-live-error').hide().detach();
            liveEntry.newTimesAlert = $('#js-new-times-alert').hide();
            liveEntry.PopulatingFromRow = false;
        },

        pusher: {
            init: function () {
                if (!liveEntry.currentEventGroupId) {
                    // Just for safety, abort this init if there is no event data
                    // and avoid breaking execution
                    return;
                }
                // Listen to push notifications

                var liveTimesPusherKey = $('#js-live-times-pusher').data('key');
                var pusher = new Pusher(liveTimesPusherKey);
                var channel = pusher.subscribe('live-times-available.event_group.' + liveEntry.currentEventGroupId);

                channel.bind('pusher:subscription_succeeded', function () {
                    // Force the server to trigger a push for initial display
                    liveEntry.triggerTimeRecordsPush();
                });

                channel.bind('update', function (data) {
                    // New value pushed from the server
                    // Display updated number of new live times on Pull Times button
                    var unconsideredCount = (typeof data.unconsidered === 'number') ? data.unconsidered : 0;
                    var unmatchedCount = (typeof data.unmatched === 'number') ? data.unmatched : 0;
                    liveEntry.pusher.displayNewCount(unconsideredCount, unmatchedCount);
                });
            },

            displayNewCount: function (unconsideredCount, unmatchedCount) {
                var unconsideredText = (unconsideredCount > 0) ? unconsideredCount : '';
                var unmatchedText = (unmatchedCount > 0) ? unmatchedCount : '';
                $('#js-pull-times-count').text(unconsideredText);
                $('#js-force-pull-times-count').text(unmatchedText);

                if (unconsideredCount > 0) {
                    $('#js-new-times-alert').fadeTo(500, 1);
                } else if ($('#js-new-times-alert').is(":visible")) {
                    $('#js-new-times-alert').fadeTo(500, 0, function () {
                        $('#js-new-times-alert').hide()
                    });
                }
            }
        },

        triggerTimeRecordsPush: function () {
            var endpoint = '/api/v1/event_groups/' + liveEntry.currentEventGroupId + '/trigger_time_records_push';
            $.ajax({
                url: endpoint,
                cache: false
            });
        },

        /**
         * Sets up eventGroupResponse and other convenience data structures
         *
         */
        dataSetup: {
            init: function (response) {
                liveEntry.eventGroupResponse = response;
                liveEntry.eventGroupAttributes = liveEntry.eventGroupResponse.data.attributes;
                liveEntry.defaultEventId = liveEntry.eventGroupResponse.data.relationships.events.data[0].id; // Remove
                this.buildBibEventMap(); // Remove
                this.buildEventIdNameMap();
                this.buildBibEffortMap();
                this.buildSplitIdIndexMap(); // Remove
                this.buildSplitNameIndexMap();
                console.log(liveEntry.splitNameIndexMap)
            },

            // Remove
            buildBibEventMap: function () {
                liveEntry.bibEventMap = {};
                liveEntry.includedResources('efforts').forEach(function (effort) {
                    liveEntry.bibEventMap[effort.attributes.bibNumber] = effort.attributes.eventId;
                });
            },

            buildEventIdNameMap: function () {
                liveEntry.eventIdNameMap = {};
                liveEntry.includedResources('events').forEach(function (event) {
                    liveEntry.eventIdNameMap[event.id] = event.attributes.shortName || event.attributes.name;
                });
            },

            buildBibEffortMap: function () {
                liveEntry.bibEffortMap = {};
                liveEntry.includedResources('efforts').forEach(function (effort) {
                    var bib = effort.attributes.bibNumber;
                    liveEntry.bibEffortMap[bib] = effort;
                    liveEntry.bibEffortMap[bib]['attributes']['eventName'] = liveEntry.eventIdNameMap[effort.attributes.eventId];
                });
            },

            // Remove
            buildSplitIdIndexMap: function () {
                liveEntry.splitIdIndexMap = {};
                liveEntry.splitsAttributes().forEach(function (splitsAttribute, i) {
                    splitsAttribute.entries.forEach(function (entry) {
                        var entrySplitIds = Object.keys(entry.eventSplitIds).map(function (k) {
                            return entry.eventSplitIds[k]
                        });
                        entrySplitIds.forEach(function (splitId) {
                            liveEntry.splitIdIndexMap[splitId] = i;
                        })
                    })
                });
            },

            buildSplitNameIndexMap: function () {
                liveEntry.splitNameIndexMap = {};
                liveEntry.splitsAttributes().forEach(function (splitsAttribute, i) {
                    var stationData = {};
                    stationData.title = splitsAttribute.title;
                    stationData.labels = splitsAttribute.entries.map(function (entry) {
                        return entry.label
                    });
                    stationData.subSplitIn = liveEntry.containsSubSplitKind(splitsAttribute.entries, 'in');
                    stationData.subSplitOut = liveEntry.containsSubSplitKind(splitsAttribute.entries, 'out');
                    liveEntry.splitNameIndexMap[i] = stationData
                })
            }
        },

        /**
         * Contains functionality for the times data cache
         *
         */
        timeRowsCache: {

            /**
             * Inits the times data cache
             *
             */
            init: function () {

                // Set the initial cache object in local storage
                this.storageId = 'timeRowsCache/' + liveEntry.serverURI + '/eventGroup/' + liveEntry.currentEventGroupId;
                var timeRowsCache = localStorage.getItem(this.storageId);
                if (timeRowsCache === null || timeRowsCache.length == 0) {
                    localStorage.setItem(this.storageId, JSON.stringify([]));
                }
            },

            /**
             * Check table stored timeRows for highest unique ID, then return a new one.
             * @return integer Unique Time Row Id
             */
            getUniqueId: function () {
                // Check table stored timeRows for highest unique ID then create a new one.
                var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                var storedUniqueIds = [];
                if (storedTimeRows.length > 0) {
                    $.each(storedTimeRows, function (index, value) {
                        storedUniqueIds.push(this.uniqueId);
                    });
                    var highestUniqueId = Math.max.apply(Math, storedUniqueIds);
                    return highestUniqueId + 1;
                } else {
                    return 0;
                }
            },

            /**
             * Get local timeRows Storage Object
             *
             * @return object Returns object from local storage
             */
            getStoredTimeRows: function () {
                return JSON.parse(localStorage.getItem(this.storageId))
            },

            /**
             * Stringify then Save/Push all timeRows to local object
             *
             * @param object timeRowsObject Pass in the object of the updated object with all added or removed objects.
             * @return null
             */
            setStoredTimeRows: function (timeRowsObject) {
                localStorage.setItem(this.storageId, JSON.stringify(timeRowsObject));
                return null;
            },

            /**
             * Delete the matching timeRow
             *
             * @param object    timeRow    Pass in the object/timeRow we want to delete.
             * @return null
             */
            deleteStoredTimeRow: function (timeRow) {
                var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                $.each(storedTimeRows, function (index) {
                    if (this.uniqueId == timeRow.uniqueId) {
                        storedTimeRows.splice(index, 1);
                        return false;
                    }
                });
                localStorage.setItem(this.storageId, JSON.stringify(storedTimeRows));
                return null;
            },

            /**
             * Compare timeRow to all timeRows in local storage. Add if it doesn't already exist, or throw an error message.
             *
             * @param  object timeRow Pass in Object of the timeRow to check it against the stored objects         *
             * @return boolean    True if match found, False if no match found
             */
            isMatchedTimeRow: function (timeRow) {
                var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                var tempTimeRow = JSON.stringify(timeRow);
                var flag = false;

                $.each(storedTimeRows, function () {
                    var loopedTimeRow = JSON.stringify($(this));
                    if (loopedTimeRow == tempTimeRow) {
                        flag = true;
                    }
                });

                if (flag == false) {
                    return false;
                } else {
                    return true;
                }
            },
        },
        /**
         * Functionality to build header lives here
         *
         */
        header: {
            init: function () {
                liveEntry.header.updateEventName();
                liveEntry.header.buildStationSelect();
            },

            /**
             * Populate the h2 with the eventName
             *
             */
            updateEventName: function () {
                $('.page-title h2').text(liveEntry.eventGroupAttributes.name);
            },

            /**
             * Add the Splits data to the select drop down table on the page
             *
             */
            buildStationSelect: function () {
                var $select = $('#js-station-select');
                // Populate select list with eventGroup station attributes
                // Sub_split_in and sub_split_out are boolean fields indicating the existence of in and out time fields respectively.
                var stationItems = '';
                for (var i in liveEntry.splitNameIndexMap) {
                    var attributes = liveEntry.splitNameIndexMap[i];
                    stationItems += '<option data-sub-split-in="' + attributes.subSplitIn + '" data-sub-split-out="' + attributes.subSplitOut + '" value="' + i + '">';
                    stationItems += attributes.title + '</option>';
                }
                $select.html(stationItems);
                // Syncronize Select with splitId
                $select.children().first().prop('selected', true);
                liveEntry.currentStationIndex = $select.val();
                this.changeStationSelect(liveEntry.currentStationIndex);

                $select.on('change', function () {
                    var targetIndex = $(this).val();
                    liveEntry.header.changeStationSelect(targetIndex);
                });
            },

            /**
             * Switches the current station to the specified Aid Station
             *
             * @param stationIndex (integer) The station index to switch to
             */
            changeStationSelect: function (stationIndex) {
                $('#js-station-select').val(stationIndex);

                var entries = liveEntry.splitsAttributes()[stationIndex].entries;
                $('#js-time-in-label').html(entries[0] && entries[0].label || '');
                $('#js-time-out-label').html(entries[1] && entries[1].label || '');

                var $selectOption = $('#js-station-select option:selected');
                $('#js-time-in').prop('disabled', !$selectOption.data('sub-split-in'));
                $('#js-pacer-in').prop('disabled', !$selectOption.data('sub-split-in'));
                $('#js-time-out').prop('disabled', !$selectOption.data('sub-split-out'));
                $('#js-pacer-out').prop('disabled', !$selectOption.data('sub-split-out'));
                $('#js-file-split').text($selectOption.text());

                if (liveEntry.currentStationIndex !== stationIndex) {
                    liveEntry.currentStationIndex = stationIndex;
                    liveEntry.liveEntryForm.fetchEffortData()
                }
            }
        },

        /**
         * Contains functionality for the timeRow form
         *
         */
        liveEntryForm: {
            lastBib: null,
            lastStationIndex: null,
            init: function () {
                // Apply input masks on time in / out
                var maskOptions = {
                    placeholder: "hh:mm:ss",
                    insertMode: false,
                    showMaskOnHover: false,
                };

                $('#js-add-effort-form [data-toggle="tooltip"]').tooltip({container: 'body'});

                $('#js-time-in').inputmask("hh:mm:ss", maskOptions);
                $('#js-time-out').inputmask("hh:mm:ss", maskOptions);
                $('#js-bib-number').inputmask("Regex", {regex: "[0-9|*]{0,6}"});
                $('#js-lap-number').inputmask("integer", {
                    min: 1,
                    max: liveEntry.eventGroupAttributes.maximumLaps || undefined
                });

                // Enable / Disable conditional fields
                var multiLap = liveEntry.includedResources('events')
                    .map(function (event) {
                        return event.attributes.multiLap
                    })
                    .reduce(function (p, c) {
                        return p || c
                    }, false);
                multiLap && $('.lap-disabled').removeClass('lap-disabled');

                var multiGroup = liveEntry.eventGroupResponse.data.relationships.events.data.length > 1;
                multiGroup && $('.group-disabled').removeClass('group-disabled');

                var pacers = liveEntry.eventGroupAttributes.monitorPacers;
                pacers && $('.pacer-disabled').removeClass('pacer-disabled');

                function anyTimes(subSplitKind) {
                    return liveEntry.splitsAttributes().map(function (splitsAttribute) {
                        return liveEntry.containsSubSplitKind(splitsAttribute.entries, subSplitKind)
                    }).reduce(function (p, c) {
                        return p || c
                    });
                }

                var anyTimesIn = anyTimes('in');
                anyTimesIn && $('.time-in-disabled').removeClass('time-in-disabled');

                var anyTimesOut = anyTimes('out');
                anyTimesOut && $('.time-out-disabled').removeClass('time-out-disabled');

                // Styles the Dropped Here button
                $('#js-dropped').on('change', function (event) {
                    var $root = $(this).parent();
                    if ($(this).prop('checked')) {
                        $root.addClass('btn-warning').removeClass('btn-default');
                        $('.glyphicon', $root).addClass('glyphicon-check').removeClass('glyphicon-unchecked');
                    } else {
                        $root.addClass('btn-default').removeClass('btn-warning');
                        $('.glyphicon', $root).addClass('glyphicon-unchecked').removeClass('glyphicon-check');
                    }
                });

                // Clears the live entry form when the clear button is clicked
                $('#js-discard-entry-form').on('click', function (event) {
                    event.preventDefault();
                    liveEntry.liveEntryForm.clearEffortData();
                    $('#js-bib-number').focus();
                    return false;
                });

                $('#js-bib-number').on('blur', function () {
                    liveEntry.liveEntryForm.updateEffortLocal();
                    liveEntry.liveEntryForm.fetchEffortData();
                });

                $('#js-lap-number').on('blur', function () {
                    liveEntry.liveEntryForm.fetchEffortData();
                });

                $('#js-time-in').on('blur', function () {
                    var timeIn = $(this).val();
                    timeIn = liveEntry.liveEntryForm.validateTimeFields(timeIn);
                    if (timeIn === false) {
                        $(this).val('');
                    } else {
                        $(this).val(timeIn);
                        liveEntry.liveEntryForm.fetchEffortData();
                    }
                });

                $('#js-time-out').on('blur', function () {
                    var timeIn = $(this).val();
                    timeIn = liveEntry.liveEntryForm.validateTimeFields(timeIn);
                    if (timeIn === false) {
                        $(this).val('');
                    } else {
                        $(this).val(timeIn);
                        liveEntry.liveEntryForm.fetchEffortData();
                    }
                });

                $('#js-rapid-time-in,#js-rapid-time-out').on('click', function (event) {
                    if ($(this).siblings('input:disabled').length) return;
                    var rapid = $(this).closest('.form-group').toggleClass('has-highlight').hasClass('has-highlight');
                    $(this).closest('.form-group').toggleClass('rapid-mode', rapid);
                });

                // Enable / Disable Rapid Entry Mode
                $('#js-rapid-mode').on('change', function (event) {
                    liveEntry.liveEntryForm.rapidEntry = $(this).prop('checked');
                    $('#js-time-in, #js-time-out').closest('.form-group').toggleClass('has-success', $(this).prop('checked'));
                }).change();


                var $droppedHereButton = $('#js-dropped-button');
                $droppedHereButton.on('click', function (event) {
                    event.preventDefault();
                    $('#js-dropped').prop('checked', !$('#js-dropped').prop('checked')).change();
                    return false;
                });
                $droppedHereButton.keypress(function (event) {
                    if (event.which === 13) {
                        event.preventDefault();
                        $('#js-add-to-cache').click()
                    }
                    return false;
                });

                $('#js-html-modal').on('show.bs.modal', function (e) {
                    $(this).find('modal-body').html('');
                    var $source = $(e.relatedTarget);
                    var $body = $(this).find('.js-modal-content');
                    if ($source.attr('data-effort-id')) {
                        var eventId = $source.attr('data-event-id');
                        var data = {
                            'effortId': $source.attr('data-effort-id')
                        };
                        $.get('/live/events/' + eventId + '/effort_table', data)
                            .done(function (a, b, c) {
                                $body.html(a);
                            });
                    } else {
                        e.preventDefault();
                    }
                });
            },

            /**
             * Updates effort information from memory without hitting the server.
             */

            updateEffortLocal: function () {
                var fullName = '';
                var effortId = '';
                var eventId = '';
                var eventName = '';
                var url = '#';
                var bib = $('#js-bib-number').val();

                if (bib !== '') {
                    var effort = liveEntry.bibEffortMap[bib];

                    if (effort !== null && typeof effort === 'object') {
                        fullName = effort.attributes.fullName;
                        effortId = effort.id;
                        eventId = effort.attributes.eventId;
                        eventName = effort.attributes.eventName;
                        // url = effort.links.self;
                    } else {
                        fullName = 'Bib not found';
                    }
                }

                $('#js-effort-name').html(fullName).attr('data-effort-id', effortId).attr('data-event-id', eventId);
                // $('#js-effort-name').attr("href", url);
                $('#js-effort-event-name').html(eventName)
            },

            /**
             * Fetches any available information for the data entered.
             */
            fetchEffortData: function () {
                var currentFormComp;
                var lastRequestComp;
                if (liveEntry.PopulatingFromRow) {
                    // Do nothing.
                    // This fn is being called from several places based on different actions.
                    // None of them are needed if the form is being populated by the system from a
                    // local row's data (i.e., if a user clicks on Edit icon in a Local Data Workspace row).
                    // PopulatingFromRow will be on while the form is populated by that action
                    // and turned off when that's done.
                    return $.Deferred().resolve();
                }
                liveEntry.liveEntryForm.prefillCurrentTime();
                var bibNumber = $('#js-bib-number').val();
                var bibChanged = (bibNumber !== liveEntry.liveEntryForm.lastBib);
                var splitChanged = (liveEntry.currentStationIndex !== liveEntry.liveEntryForm.lastStationIndex);
                liveEntry.liveEntryForm.lastBib = bibNumber;
                liveEntry.liveEntryForm.lastStationIndex = liveEntry.currentStationIndex;

                currentFormComp = liveEntry.rawTimeRow.compData(liveEntry.rawTimeRow.currentForm());
                lastRequestComp = liveEntry.rawTimeRow.compData(liveEntry.rawTimeRow.lastRequest);

                if (JSON.stringify(currentFormComp) === JSON.stringify(lastRequestComp)) {
                    return $.Deferred().resolve(); // We already have the information for this data.
                }

                return $.get('/api/v1/event_groups/' + liveEntry.currentEventGroupId + '/verify_raw_times', data, function (response) {
                    $('#js-live-bib').val('true');
                    if (!$('#js-lap-number').val() || bibChanged || splitChanged) {
                        $('#js-lap-number').val(response.lap);
                        $('#js-lap-number:focus').select();
                    }

                    $('#js-bib-number')
                        .removeClass('null bad questionable good')
                        .addClass(liveEntry.bibStatus(response));
                    $('#js-time-in')
                        .removeClass('exists null bad good questionable')
                        .addClass(response.timeInExists ? 'exists' : '')
                        .addClass(response.timeInStatus);
                    $('#js-time-out')
                        .removeClass('exists null bad good questionable')
                        .addClass(response.timeOutExists ? 'exists' : '')
                        .addClass(response.timeOutStatus);

                    liveEntry.currentEffortData = response;
                    liveEntry.rawTimeRow.lastRequest = currentFormComp;
                })
            },

            /**
             * Retrieves the entire form formatted as a timerow
             * @return {[type]} [description]
             */
            getTimeRow: function () {
                if ($('#js-bib-number').val() == '' &&
                    $('#js-time-in').val() == '' &&
                    $('#js-time-out').val() == '') {
                    return null;
                }

                var thisTimeRow = {};
                thisTimeRow.stationIndex = liveEntry.currentStationIndex;
                thisTimeRow.liveBib = $('#js-live-bib').val();
                thisTimeRow.lap = $('#js-lap-number').val();
                thisTimeRow.bibNumber = $('#js-bib-number').val();
                thisTimeRow.eventId = liveEntry.eventIdFromBib(thisTimeRow.bibNumber);
                thisTimeRow.splitId = liveEntry.getSplitId(thisTimeRow.eventId, liveEntry.currentStationIndex);
                thisTimeRow.effortId = liveEntry.currentEffortData.effortId;
                thisTimeRow.effortName = $('#js-effort-name').html();
                thisTimeRow.eventName = $('#js-effort-event-name').html();
                thisTimeRow.timeIn = $('#js-time-in:not(:disabled)').val() || '';
                thisTimeRow.timeOut = $('#js-time-out:not(:disabled)').val() || '';
                thisTimeRow.pacerIn = $('#js-pacer-in:not(:disabled)').prop('checked') || false;
                thisTimeRow.pacerOut = $('#js-pacer-out:not(:disabled)').prop('checked') || false;
                thisTimeRow.droppedHere = $('#js-dropped').prop('checked');
                thisTimeRow.timeInStatus = liveEntry.currentEffortData.timeInStatus;
                thisTimeRow.timeOutStatus = liveEntry.currentEffortData.timeOutStatus;
                thisTimeRow.timeInExists = liveEntry.currentEffortData.timeInExists;
                thisTimeRow.timeOutExists = liveEntry.currentEffortData.timeOutExists;
                thisTimeRow.liveTimeIdIn = $('#js-live-time-id-in').val() || '';
                thisTimeRow.liveTimeIdOut = $('#js-live-time-id-out').val() || '';
                return thisTimeRow;
            },

            loadTimeRow: function (timeRow) {
                liveEntry.lastEffortRequest = {};
                liveEntry.currentEffortData = timeRow;
                $('#js-bib-number').val(timeRow.bibNumber).focus();
                $('#js-lap-number').val(timeRow.lap);
                $('#js-time-in').val(timeRow.timeIn);
                $('#js-time-out').val(timeRow.timeOut);
                $('#js-pacer-in').prop('checked', timeRow.pacerIn);
                $('#js-pacer-out').prop('checked', timeRow.pacerOut);
                $('#js-dropped').prop('checked', timeRow.droppedHere).change();
                $('#js-live-time-id-in').val(timeRow.liveTimeIdIn);
                $('#js-live-time-id-out').val(timeRow.liveTimeIdOut);
                liveEntry.header.changeStationSelect(timeRow.stationIndex);
            },

            /**
             * Clears out the entry form and effort detail data fields
             * @param  {Boolean} clearForm Determines if the form is cleared as well.
             */
            clearEffortData: function () {
                $('#js-effort-name').html('').removeAttr('href');
                $('#js-effort-event-name').html('');
                $('#js-time-in').removeClass('exists null bad good questionable');
                $('#js-time-out').removeClass('exists null bad good questionable');
                liveEntry.lastEffortRequest = {};
                $('#js-time-in').val('');
                $('#js-time-out').val('');
                $('#js-live-bib').val('');
                $('#js-bib-number').val('');
                $('#js-lap-number').val('');
                $('#js-pacer-in').prop('checked', false);
                $('#js-pacer-out').prop('checked', false);
                $('#js-dropped').prop('checked', false).change();
                liveEntry.liveEntryForm.fetchEffortData();
            },

            /**
             * Validates the time fields
             *
             * @param string time time format from the input mask
             */
            validateTimeFields: function (time) {
                time = time.replace(/\D/g, '');
                if (time.length == 0) return time;
                if (time.length < 2) return false;
                while (time.length < 6) {
                    time = time.concat('0');
                }
                return time;
            },
            /**
             * Returns the current time in the standard format
             */
            currentTime: function () {
                var now = new Date();
                return ("0" + now.getHours()).slice(-2) + ("0" + now.getMinutes()).slice(-2) + ("0" + now.getSeconds()).slice(-2);
            },
            /**
             * Prefills the time fields with the current time
             */
            prefillCurrentTime: function () {
                if ($('#js-bib-number').val() == '') {
                    $('.rapid-mode #js-time-in').val('');
                    $('.rapid-mode #js-time-out').val('');
                } else if ($('#js-bib-number').val() != liveEntry.liveEntryForm.lastBib) {
                    $('.rapid-mode #js-time-in:not(:disabled)').val(liveEntry.liveEntryForm.currentTime());
                    $('.rapid-mode #js-time-out:not(:disabled)').val(liveEntry.liveEntryForm.currentTime());
                }
            }
        }, // END liveEntryForm form

        /**
         * Contains functionality for times data cache table
         *
         * timeRows need to send back the following fields:
         *      - effortId
         *      - splitId
         *      - timeIn (military)
         *      - timeOut (military)
         *      - PacerIn: (bool)
         *      - PacerOut: (bool)
         */
        timeRowsTable: {

            /**
             * Stores the object from DataTable
             *
             * @type object
             */
            $dataTable: null,
            busy: false,

            /**
             * Inits the provisional data table
             *
             */
            init: function () {

                // Initiate DataTable Plugin
                liveEntry.timeRowsTable.$dataTable = $('#js-local-workspace-table').DataTable({
                    pageLength: 50,
                    oLanguage: {
                        'sSearch': 'Filter:&nbsp;'
                    }
                });
                liveEntry.timeRowsTable.$dataTable.clear().draw();
                liveEntry.timeRowsTable.populateTableFromCache();
                liveEntry.timeRowsTable.timeRowControls();

                $('[data-toggle="popover"]').popover();
                liveEntry.timeRowsTable.$dataTable.on('mouseover', '[data-toggle="tooltip"]', function () {
                    $(this).tooltip('show');
                });

                // Attach add listener
                $('#js-add-to-cache').on('click', function (event) {
                    event.preventDefault();
                    liveEntry.liveEntryForm.prefillCurrentTime();
                    liveEntry.timeRowsTable.addTimeRowFromForm();
                    return false;
                });

                // Wrap search field with clear button
                $('#js-local-workspace-table_filter input')
                    .wrap('<div class="form-group form-group-sm has-feedback"></div>')
                    .on('change keyup', function () {
                        var value = $(this).val() || '';
                        if (value.length > 0) {
                            $('#js-filter-clear').show();
                        } else {
                            $('#js-filter-clear').hide();
                        }
                    });
                $('#js-local-workspace-table_filter .form-group').append(
                    '<span id="js-filter-clear" class="glyphicon glyphicon-remove dataTables_filter-clear form-control-feedback" aria-hidden="true"></span>'
                );
                $('#js-filter-clear').on('click', function () {
                    liveEntry.timeRowsTable.$dataTable.search('').draw();
                    $(this).hide();
                });
            },

            populateTableFromCache: function () {
                var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                $.each(storedTimeRows, function (index) {
                    liveEntry.timeRowsTable.addTimeRowToTable(this, false);
                });
                liveEntry.timeRowsTable.$dataTable.draw();
            },

            addTimeRowFromForm: function () {
                // Retrieve form data
                liveEntry.liveEntryForm.fetchEffortData().always(function () {
                    var thisTimeRow = liveEntry.liveEntryForm.getTimeRow();
                    if (thisTimeRow == null) {
                        return;
                    }
                    thisTimeRow.uniqueId = liveEntry.timeRowsCache.getUniqueId();

                    var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                    if (!liveEntry.timeRowsCache.isMatchedTimeRow(thisTimeRow)) {
                        storedTimeRows.push(thisTimeRow);
                        liveEntry.timeRowsCache.setStoredTimeRows(storedTimeRows);
                        liveEntry.timeRowsTable.addTimeRowToTable(thisTimeRow);
                    }

                    // Clear data and put focus on bibNumber field once we've collected all the data
                    liveEntry.liveEntryForm.clearEffortData();
                    $('#js-bib-number').focus();
                });
            },

            /**
             * Add a new row to the table (with js dataTables enabled)
             *
             * @param object timeRow Pass in the object of the timeRow to add
             * @param boolean highlight If true, the new row will flash when it is added.
             */
            addTimeRowToTable: function (timeRow, highlight) {
                highlight = (typeof highlight == 'undefined') || highlight;
                liveEntry.timeRowsTable.$dataTable.search('');
                $('#js-filter-clear').hide();
                var bib_icons = {
                    'good': '&nbsp;<span class="glyphicon glyphicon-ok-sign text-success" data-toggle="tooltip" title="Bib Found"></span>',
                    'questionable': '&nbsp;<span class="glyphicon glyphicon-question-sign text-warning" data-toggle="tooltip" title="Bib In Wrong Event"></span>',
                    'bad': '&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" data-toggle="tooltip" title="Bib Not Found"></span>'
                };
                var time_icons = {
                    'exists': '&nbsp;<span class="glyphicon glyphicon-exclamation-sign" data-toggle="tooltip" title="Data Already Exists"></span>',
                    'good': '&nbsp;<span class="glyphicon glyphicon-ok-sign text-success" data-toggle="tooltip" title="Time Appears Good"></span>',
                    'questionable': '&nbsp;<span class="glyphicon glyphicon-question-sign text-warning" data-toggle="tooltip" title="Time Appears Questionable"></span>',
                    'bad': '&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" data-toggle="tooltip" title="Time Appears Bad"></span>'
                };
                var bibNumberIcon = bib_icons[liveEntry.bibStatus(timeRow)] || '';
                var timeInIcon = time_icons[timeRow.timeInStatus] || '';
                timeInIcon += (timeRow.timeInExists && timeRow.timeIn) ? time_icons['exists'] : '';
                var timeOutIcon = time_icons[timeRow.timeOutStatus] || '';
                timeOutIcon += (timeRow.timeOutExists && timeRow.timeOut) ? time_icons['exists'] : '';

                // Base64 encode the stringifyed timeRow to add to the timeRow
                var base64encodedTimeRow = btoa(JSON.stringify(timeRow));
                var trHtml = '\
                    <tr class="effort-station-row js-effort-station-row" data-unique-id="' + timeRow.uniqueId + '" data-encoded-effort="' + base64encodedTimeRow + '"\
                        data-live-time-id-in="' + timeRow.liveTimeIdIn + '"\
                        data-live-time-id-out="' + timeRow.liveTimeIdOut + '"\
                        data-event-id="' + timeRow.eventId + '"\>\
                        <td class="station-title js-station-title" data-order="' + timeRow.stationIndex + '">' + (liveEntry.splitNameIndexMap[timeRow.stationIndex] || {title: 'Unknown'}).title + '</td>\
                        <td class="lap-number js-lap-number group-only">' + liveEntry.eventIdNameMap[timeRow.eventId] + '</td>\
                        <td class="bib-number js-bib-number ' + liveEntry.bibStatus(timeRow) + '">' + (timeRow.bibNumber || '') + bibNumberIcon + '</td>\
                        <td class="effort-name js-effort-name text-nowrap">' + timeRow.effortName + '</td>\
                        <td class="lap-number js-lap-number lap-only">' + timeRow.lap + '</td>\
                        <td class="time-in js-time-in text-nowrap time-in-only ' + timeRow.timeInStatus + '">' + (timeRow.timeIn || '') + timeInIcon + '</td>\
                        <td class="time-out js-time-out text-nowrap time-out-only ' + timeRow.timeOutStatus + '">' + (timeRow.timeOut || '') + timeOutIcon + '</td>\
                        <td class="pacer-inout js-pacer-inout pacer-only">' + (timeRow.pacerIn ? 'Yes' : 'No') + ' / ' + (timeRow.pacerOut ? 'Yes' : 'No') + '</td>\
                        <td class="dropped-here js-dropped-here">' + (timeRow.droppedHere ? '<span class="btn btn-warning btn-xs disabled">Dropped Here</span>' : '') + '</td>\
                        <td class="row-edit-btns">\
                            <button class="effort-row-btn fa fa-pencil edit-effort js-edit-effort btn btn-primary"></button>\
                            <button class="effort-row-btn fa fa-close delete-effort js-delete-effort btn btn-danger"></button>\
                            <button class="effort-row-btn fa fa-check submit-effort js-submit-effort btn btn-success"></button>\
                        </td>\
                    </tr>';
                var node = liveEntry.timeRowsTable.$dataTable.row.add($(trHtml)).draw('full-hold');
                if (highlight) {
                    // Find page that the row was added to
                    var pageInfo = liveEntry.timeRowsTable.$dataTable.page.info();
                    var index = liveEntry.timeRowsTable.$dataTable.rows().indexes().indexOf(node.index());
                    var pageIndex = Math.floor(index / pageInfo.length);
                    liveEntry.timeRowsTable.$dataTable.page(pageIndex).draw('full-hold');
                    $(node.node()).effect('highlight', 2000);
                }
            },

            removeTimeRows: function (timeRows) {
                $.each(timeRows, function (index) {
                    var $row = $(this).closest('tr');
                    var timeRow = JSON.parse(atob($row.attr('data-encoded-effort')));

                    // remove timeRow from cache
                    liveEntry.timeRowsCache.deleteStoredTimeRow(timeRow);

                    // remove table row
                    $row.fadeOut('fast', function () {
                        liveEntry.timeRowsTable.$dataTable.row($row).remove().draw('full-hold');
                    });
                });
            },

            submitTimeRows: function (tableNodes, forceSubmit) {
                if (liveEntry.timeRowsTable.busy) return;
                liveEntry.timeRowsTable.busy = true;

                var timeRows = [];

                $.each(tableNodes, function () {
                    var $row = $(this).closest('tr');
                    var timeRow = JSON.parse(atob($row.attr('data-encoded-effort')));
                    timeRows.push(timeRow);
                });

                var eventsObj = {};

                timeRows.forEach(function (row) {
                    var eventId = row.eventId;
                    if (eventsObj[eventId]) {
                        eventsObj[eventId].push(row);
                    } else {
                        eventsObj[eventId] = [row];
                    }
                });

                for (var eventId in eventsObj) {
                    var data = {timeRows: eventsObj[eventId], forceSubmit: forceSubmit};
                    $.post('/api/v1/events/' + eventId + '/set_times_data', data, function (response) {
                        liveEntry.timeRowsTable.removeTimeRows(tableNodes);
                        liveEntry.timeRowsTable.$dataTable.rows().nodes().to$().stop(true, true);
                        for (var i = 0; i < response.returnedRows.length; i++) {
                            var timeRow = response.returnedRows[i];
                            timeRow.uniqueId = liveEntry.timeRowsCache.getUniqueId();

                            var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                            if (!liveEntry.timeRowsCache.isMatchedTimeRow(timeRow)) {
                                storedTimeRows.push(timeRow);
                                liveEntry.timeRowsCache.setStoredTimeRows(storedTimeRows);
                                liveEntry.timeRowsTable.addTimeRowToTable(timeRow);
                            }
                        }
                    }).always(function () {
                        liveEntry.timeRowsTable.busy = false;
                    });
                }
            },

            /**
             * Toggles the current state of the discard all button
             * @param  boolean forceClose The button is forced to close without discarding.
             */
            toggleDiscardAll: (function () {
                var $deleteWarning = null;
                var callback = function () {
                    liveEntry.timeRowsTable.toggleDiscardAll(false);
                };
                document.addEventListener("turbolinks:load", function () {
                    $deleteWarning = $('#js-delete-all-warning').hide().detach();
                });
                return function (canDelete) {
                    var nodes = liveEntry.timeRowsTable.$dataTable.rows().nodes();
                    var $deleteButton = $('#js-delete-all-efforts');
                    $deleteButton.prop('disabled', true);
                    $(document).off('click', callback);
                    $deleteWarning.insertAfter($deleteButton).animate({
                        width: 'toggle',
                        paddingLeft: 'toggle',
                        paddingRight: 'toggle'
                    }, {
                        duration: 350,
                        done: function () {
                            $deleteButton.prop('disabled', false);
                            if ($deleteButton.hasClass('confirm')) {
                                if (canDelete) {
                                    liveEntry.timeRowsTable.removeTimeRows(nodes);
                                    $('#js-station-select').focus();
                                }
                                $deleteButton.removeClass('confirm');
                                $deleteWarning = $('#js-delete-all-warning').hide().detach();
                            } else {
                                $deleteButton.addClass('confirm');
                                $(document).one('click', callback);
                            }
                        }
                    });
                }
            })(),

            /**
             * Move a "cached" table row to "top form" section for editing.
             *
             */
            timeRowControls: function () {

                $(document).on('click', '.js-edit-effort', function (event) {
                    liveEntry.PopulatingFromRow = true;
                    event.preventDefault();
                    liveEntry.timeRowsTable.addTimeRowFromForm();
                    var $row = $(this).closest('tr');
                    var clickedTimeRow = JSON.parse(atob($row.attr('data-encoded-effort')));

                    liveEntry.timeRowsTable.removeTimeRows($(this));

                    liveEntry.liveEntryForm.loadTimeRow(clickedTimeRow);
                    liveEntry.PopulatingFromRow = false;
                    liveEntry.liveEntryForm.fetchEffortData();
                });

                $(document).on('click', '.js-delete-effort', function () {
                    liveEntry.timeRowsTable.removeTimeRows($(this));
                });

                $(document).on('click', '.js-submit-effort', function () {
                    liveEntry.timeRowsTable.submitTimeRows([$(this).closest('tr')], true);
                });


                $('#js-delete-all-efforts').on('click', function (event) {
                    event.preventDefault();
                    liveEntry.timeRowsTable.toggleDiscardAll(true);
                    return false;
                });

                $('#js-submit-all-efforts').on('click', function (event) {
                    event.preventDefault();
                    var nodes = liveEntry.timeRowsTable.$dataTable.rows().nodes();
                    liveEntry.timeRowsTable.submitTimeRows(nodes, false);
                    return false;
                });

                $('#js-file-upload').fileupload({
                    dataType: 'json',
                    url: '/api/v1/events/' + liveEntry.defaultEventId + '/post_file_effort_data',
                    submit: function (e, data) {
                        data.formData = {splitId: liveEntry.getSplitId(liveEntry.defaultEventId, liveEntry.currentStationIndex)};
                        liveEntry.timeRowsTable.busy = true;
                    },
                    done: function (e, data) {
                        liveEntry.populateRows(data.result);
                    },
                    fail: function (e, data) {
                        $('#debug').empty().append(data.response().jqXHR.responseText);
                    },
                    always: function () {
                        liveEntry.timeRowsTable.busy = false;
                    }
                });

                $(document).on('keydown', function (event) {
                    if (event.keyCode === 16) {
                        $('#js-import-live-times').hide();
                        $('#js-force-import-live-times').show()
                    }
                });
                $(document).on('keyup', function (event) {
                    if (event.keyCode === 16) {
                        $('#js-force-import-live-times').hide();
                        $('#js-import-live-times').show()
                    }
                });
                $('#js-import-live-times, #js-force-import-live-times').on('click', function (event) {
                    event.preventDefault();
                    if (liveEntry.importAsyncBusy) {
                        return;
                    }
                    liveEntry.importAsyncBusy = true;
                    var forceParam = (this.id === 'js-force-import-live-times') ? '?forcePull=true' : '';
                    $.ajax('/api/v1/event_groups/' + liveEntry.currentEventGroupId + '/pull_live_time_rows' + forceParam, {
                        error: function (obj, error) {
                            liveEntry.importAsyncBusy = false;
                            liveEntry.timeRowsTable.importLiveError(obj, error);
                        },
                        dataType: 'json',
                        success: function (data) {
                            if (data.returnedRows.length === 0) {
                                liveEntry.displayAndHideMessage(
                                    liveEntry.importLiveWarning,
                                    '#js-import-live-warning');
                                return;
                            }
                            liveEntry.populateRows(data);
                            liveEntry.importAsyncBusy = false;
                        },
                        type: 'PATCH'
                    });
                    return false;
                });
            },
            importLiveError: function (obj, error) {
                liveEntry.displayAndHideMessage(liveEntry.importLiveError, '#js-import-live-error');
            }
        }, // END timeRowsTable

        rawTimeRow: {
            currentResponse: {},
            lastRequest: {},

            compData: function (row) {
                row['rawTimes'].map(function (rawTime) {
                    return {
                        bibNumber: rawTime.bibNumber,
                        enteredTime: rawTime.enteredTime,
                        lap: rawTime.lap,
                        splitName: rawTime.splitName,
                        subSplitKind: rawTime.subSplitKind,
                        stoppedHere: rawTime.stoppedHere
                    }
                })
            },

            currentForm: function () {
                var subSplitKinds = ['in', 'out'];

                subSplitKinds.map(function(kind) {
                    return {
                        rawTimes: {
                            eventGroupId: liveEntry.currentEventGroupId,
                            bibNumber: $('#js-bib-number').val(),
                            enteredTime: $('#js-time-' + kind).val(),
                            lap: $('js-lap').val(),
                            splitName: liveEntry.splitNameIndexMap[liveEntry.currentStationIndex].title,
                            subSplitKind: kind,
                            stoppedHere: $('#js-dropped').prop('checked'),
                            withPacer: $('#js-pacer-' + kind).prop('checked')
                        }
                    }

                })
            }
        }, // END rawTimeRow

        displayAndHideMessage: function (msgElement, selector) {
            // Fade in and fade out Bootstrap Alert
            // @param msgElement object jQuery element containing the alert
            // @param selector string jQuery selector to access the alert element
            $('#js-live-messages').append(msgElement);
            msgElement.fadeTo(500, 1);
            window.setTimeout(function () {
                msgElement.fadeTo(500, 0).slideUp(500, function () {
                    msgElement = $(selector).hide().detach();
                    liveEntry.importAsyncBusy = false;
                });
            }, 4000);
            return;
        },
        populateRows: function (response) {
            response.returnedRows.forEach(function (timeRow) {
                timeRow.uniqueId = liveEntry.timeRowsCache.getUniqueId();

                // Rows coming in from an imported file or from pull_live_time_rows have no stationIndex
                timeRow.stationIndex = timeRow.stationIndex || liveEntry.splitIdIndexMap[timeRow.splitId];

                var storedTimeRows = liveEntry.timeRowsCache.getStoredTimeRows();
                if (!liveEntry.timeRowsCache.isMatchedTimeRow(timeRow)) {
                    storedTimeRows.push(timeRow);
                    liveEntry.timeRowsCache.setStoredTimeRows(storedTimeRows);
                    liveEntry.timeRowsTable.addTimeRowToTable(timeRow);
                }
            })
        } // END populateRows
    }; // END liveEntry

    document.addEventListener("turbolinks:load", function () {
        if (Rails.$('.event_groups.live_entry')[0] === document.body) {
            liveEntry.init();
        }
    });

})(jQuery);