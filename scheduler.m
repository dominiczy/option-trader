classdef scheduler < handle
    % Starts downloadloader runs periodically to format new results (and
    % maybe set last in priceOptionTable).
    
    properties
        stocks;
        currentIndex;
        state = 0; % 0 first page, 1 other pages, 2 format, 3 save to file, 4 add to stock, 
        % 5 download all history, 6 download latest history, 7 format all history, 8 format latest history, 9 save all history, 10 merge latest history with all, 11 reload from files, -1 error
        myDownloader;
    end
    
    methods
        function obj = scheduler (stocks)
            fprintf('Constructing scheduler.\n')
            obj.stocks = stocks;
            obj.currentIndex = 1;
            stock = obj.stocks{obj.currentIndex};
            obj.myDownloader = downloader (stock.symbol);
            tmr = timer('TimerFcn', @obj.timerCallback, 'ErrorFcn', @obj.timerErrCallback, 'StopFcn', @obj.timerStopCallback);
            tmr.ExecutionMode = 'singleShot';
            tmr.BusyMode = 'drop';
            tmr.period = namedConst.timerPeriodBig;
            tmr.StartDelay = 0;
            start(tmr);
        end

        
        function timerCallback (obj, source, event)
            if namedConst.downloadVerbose
                fprintf('/c')
            end
            
            stock = obj.stocks{obj.currentIndex}; 
            if class(stock) == 'tableF'
                hasOptions = 1;
            else
                hasOptions = 0;
            end
            
            if obj.state == 0 || obj.state == 1 || obj.state == 5 || obj.state == 6 % start or middle of download cycle
                obj.state = obj.myDownloader.getTablePage (obj.state, hasOptions);
                if obj.state == 0
                    stop (source);
                end
            elseif obj.state == 2 || obj.state == 7 || obj.state == 8 % all downloaded
                obj.state = obj.myDownloader.formatTablePage (obj.state);
            elseif obj.state == 3 || obj.state == 9 || obj.state == 10  % all formatted
                obj.state = obj.myDownloader.saveTablePage (obj.state);
            elseif obj.state == 4 % all saved
                stock.addDownloadedPages (obj.myDownloader.timestampNum);
                obj.state = 0;
                stop(source);
            elseif obj.state == 11 % all saved
                stock = obj.stocks{obj.currentIndex}; 
                stock.loadFromFiles();
                if hasOptions
                    obj.state = 2; % go back to formatting option data
                else
                    obj.state = 0;
                    stop(source);
                end
            end
        end
        
        function timerStopCallback (obj, source, event)
            if namedConst.downloadVerbose
                fprintf('/x')
            end
            % if error do not start again
            if obj.state > -1
                if obj.state == 1 % in middle of download cycle
                    source.Period = namedConst.timerPeriodSmall;
                    source.StartDelay = 0;
                    source.ExecutionMode = 'fixedSpacing';
                    start(source);
                else % between download cycles
                    source.Period = namedConst.timerPeriodBig;
                    source.StartDelay = namedConst.timerPeriodBig;
                    source.ExecutionMode = 'singleShot';
                    source.UserData = struct('expDateIdx', 1);
                    % move to next stock
                    obj.currentIndex = obj.currentIndex + 1;
                    % if all stocks are done start from beginning
                    if obj.currentIndex > numel(obj.stocks)
                        obj.currentIndex = 1;
                    end
                    stock = obj.stocks{obj.currentIndex};
                    obj.myDownloader.setSymbol(stock.symbol);
                    % restart timer if market is open (or if debugging)
                    if obj.currentIndex ~= 1 || myPortfolio.isMarketOpen () 
                        start(source);
                    else
						if namedConst.warnings
							warning('Scheduler not started again.')
						end
                    end
                end
            end
        end
        
        function timerErrCallback (obj, source, errorStruct)
            stock = obj.stocks{obj.currentIndex};
            % show message and stop timer
            obj.state = -1;
            warning(['Error in timer. Timer will be stopped. Stock was ' stock.symbol '. Error: ' errorStruct.Data.message])
        end
    end
    
end

