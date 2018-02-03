classdef downloader < handle
    %UNTITLED4 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        symbol;
        timestampNum;
        timestamp;
        histTimestampNum;
        histTimestamp;
        pricePage;
        optionPage;
        expDatesPosix;
        histFull;
        histAdd;
    end
    
    properties (Constant)
        yahooQueryUrlBase = 'https://query2.finance.yahoo.com/v7/finance/options/'
%         Straddle struct is more complicated
%         yahooQueryUrlOpt = '?straddle=true'
        downloadRetries = 3;
        timerPeriod = 1;
        alphaVantageQueryUrlBaseDaily = 'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY_ADJUSTED&symbol='
    end
    
    methods
        function obj = downloader (symbol)
            obj.setSymbol(symbol);
        end
        
        function setSymbol (obj, symbol)
            obj.symbol = symbol;
        end
        
        function state = getTablePage (obj, state, hasOptions)
            if namedConst.downloadVerbose
                fprintf('/p')
            end
            if state == 0 % beginning of download cycle
                obj.timestampNum = now;
                if hasOptions
                    % fetch for first date (default if not specifying date)
                    queryUrl = [downloader.yahooQueryUrlBase obj.symbol];
                    options = weboptions('Timeout', 20);
                    structDate = downloader.safeWebRead(queryUrl, options);
                    % load remaining posix time expiration dates from result
                    obj.expDatesPosix = structDate.optionChain.result.expirationDates(2:end);
                    % extract price info from result
                    obj.pricePage = struct2table(structDate.optionChain.result.quote);
                    try
                        call = struct2table(structDate.optionChain.result.options.calls);
                        put = struct2table(structDate.optionChain.result.options.puts);
                        obj.optionPage = innerjoin(call, put, 'Keys', {'strike', 'expiration'});
                    catch ME
                        if namedConst.downloadVerbose
                            warning([obj.symbol ': Posix exp date ' num2str(obj.expDatesPosix(1)) ' omitted. Error: ' ME.message])
                        end
                    end
                end
                state = state + 1;
                
            elseif state == 1 % middle of download cycle, download for next expDate
                if hasOptions
                    queryUrl = [downloader.yahooQueryUrlBase obj.symbol '?date=' num2str(obj.expDatesPosix(1))];
                    options = weboptions('Timeout', 20);
                    structDate = downloader.safeWebRead(queryUrl, options);
                    try
                        call = struct2table(structDate.optionChain.result.options.calls);
                        put = struct2table(structDate.optionChain.result.options.puts);
                        try
                            obj.optionPage = vertcat(obj.optionPage, innerjoin(call, put, 'Keys', {'strike', 'expiration'}));
                        catch
                            % this should happen in case the first posix date
                            % was omitted
                            obj.optionPage = innerjoin(call, put, 'Keys', {'strike', 'expiration'});
                        end
                    catch ME
                        if namedConst.downloadVerbose
                            warning([obj.symbol ': Posix exp date ' num2str(obj.expDatesPosix(1)) ' omitted. Error: ' ME.message])
                        end
                    end
                    % remove downloaded expDate
                    obj.expDatesPosix = obj.expDatesPosix(2:end);
                else
                    obj.expDatesPosix = [];
                end
                if isempty(obj.expDatesPosix)
                    histFile = dir([namedConst.histFolder obj.symbol '_*_' namedConst.histEnd namedConst.pageExtension]);  
                    if isempty(histFile) % no history yet
                        state = 5;
                    else	
                        timeNY = datetime('now','TimeZone','America/New_York');
                        try
                            obj.histTimestampNum = str2double(erase(histFile.name, {[obj.symbol '_'], ['_' namedConst.histEnd '.csv']}));
                        catch ME
                            error(['Error setting histTimestampNum. Probably there is more than one histFile. Error: ' ME.message])
                        end
                        obj.histTimestamp = datetime(datetime(obj.histTimestampNum, 'ConvertFrom', 'datenum','TimeZone','local'),'TimeZone','America/New_York');
                        if ~hasOptions || obj.histTimestamp < myPortfolio.getMarketCloseTime(busdate(timeNY, 'previous')) || (~isweekend(timeNY) && timeNY > myPortfolio.getMarketCloseTime() && obj.histTimestamp < timeNY) % history is out of date if datenum older than previous business day at market close or if today is busday and after marketclose
                            state = 6;
                        else
                            state = state + 1;
                        end
                    end
                end           
            elseif state == 5
                queryUrl = [downloader.alphaVantageQueryUrlBaseDaily obj.symbol '&outputsize=full&apikey=' namedConst.alphaVantageKey];
                options = weboptions('Timeout', 20);
                obj.histFull = downloader.safeWebRead(queryUrl, options);
                state = 7;
            elseif state == 6
                queryUrl = [downloader.alphaVantageQueryUrlBaseDaily obj.symbol '&outputsize=compact&apikey=' namedConst.alphaVantageKey];
                options = weboptions('Timeout', 20);
                obj.histAdd = downloader.safeWebRead(queryUrl, options);
                state = 8;
            end
%                     fetch(yahoo,symbol)
        end
        
        
    %   -pricePage: timeTable with following varNames:
    %       timestamp | last | open | high | low | prevClose | volume |
    %       dividendAmount (also add for future dates) | earnings (boolean, also for
    %       future dates)
    %   -optionPage: tall timetable
    %       timestamp | callLast | callChg | callBid | callAsk | callVol | callOpenInt |
    %       | expDate | strike | 
    %           putLast | putChg | putBid | putAsk | putVol | putOpenInt
        
        function state = formatTablePage (obj, state)
            if namedConst.downloadVerbose
                fprintf('/f')
            end
            if state == 2
                % convert local datenum to datetime for NY
                obj.timestamp = datetime(datetime(obj.timestampNum, 'ConvertFrom', 'datenum','TimeZone','local'),'TimeZone','America/New_York');
                timestamp = obj.timestamp;
                % FIXME check if we're not throwing away useful stuff
                % pricePage
                last = obj.pricePage.regularMarketPrice;
                open = obj.pricePage.regularMarketOpen;
                high = obj.pricePage.regularMarketDayHigh;
                low = obj.pricePage.regularMarketDayLow;
                prevClose = obj.pricePage.regularMarketPreviousClose;
                volume = obj.pricePage.regularMarketVolume;
                adjClose = NaN(numel(last),1);
                dividendAmount = NaN(numel(last),1);
                splitCoeff = NaN(numel(last),1);
                obj.pricePage = table(timestamp, last, open, high, low, prevClose, volume, adjClose, dividendAmount, splitCoeff);

                % optionPage
                expDate = datetime(obj.optionPage.expiration, 'ConvertFrom', 'posixtime', 'Format', namedConst.dateTimeFormatShort);
                strike = obj.optionPage.strike;
                timestamp = reshape(repelem(obj.timestamp, numel(strike)), [numel(strike), 1]);
                callBid = obj.optionPage.bid_call;
                callAsk = obj.optionPage.ask_call;
                callLast = obj.optionPage.lastPrice_call;
                callChg = obj.optionPage.change_call;
                callVol = obj.optionPage.volume_call;
                callOpenInt = obj.optionPage.openInterest_call;
                putBid = obj.optionPage.bid_put;
                putAsk = obj.optionPage.ask_put;
                putLast = obj.optionPage.lastPrice_put;
                putChg = obj.optionPage.change_put;
                putVol = obj.optionPage.volume_put;
                putOpenInt = obj.optionPage.openInterest_put;
                obj.optionPage = table(timestamp, callLast, callChg, callBid, callAsk, callVol, callOpenInt, expDate, strike, putLast, putChg, putBid, putAsk, putVol, putOpenInt);
                state = state + 1;
            elseif state == 7 || state == 8
                if state == 7
                    hist = obj.histFull;
                elseif state == 8
                    hist = obj.histAdd;
                end
                % format obj.histFull 
                rowNames = fieldnames(hist.TimeSeries_Daily_);

                histTimeStampUnset = true;
                histNew = [];
                for row = 1:length(rowNames)  
                    histAdd = struct2table(hist.TimeSeries_Daily_.(rowNames{row}));
                    try
                        timestamp = datetime(rowNames{row}(2:end), 'InputFormat','yyyy_MM_dd','TimeZone','America/New_York') + hours(16);
                        if  timestamp > datetime('now','TimeZone','America/New_York') % skip if today and market open
                            continue
                        end
                        if histTimeStampUnset
                            obj.histTimestampNum = datenum(datetime(myPortfolio.getMarketCloseTime(timestamp),'TimeZone','local'));
                            histTimeStampUnset = false;
                        end
                    catch ME
                        % if first row includes time of day
						if namedConst.warnings
							warning(['Hist data row ' num2str(row) ' omitted. Error: ' ME.message])
						end
                        continue
                    end
                    if state == 8 && timestamp < obj.histTimestamp 
                        % if data already included
                        break
                    end
                    last = str2double(histAdd.x4_Close);
                    open = str2double(histAdd.x1_Open);
                    high = str2double(histAdd.x2_High);
                    low =  str2double(histAdd.x3_Low);
                    prevClose = NaN;
                    volume = str2double(histAdd.x6_Volume);
                    adjClose = str2double(histAdd.x5_AdjustedClose);
                    dividendAmount = str2double(histAdd.x7_DividendAmount);
                    splitCoeff = str2double(histAdd.x8_SplitCoefficient);
                    histAdd = table(timestamp, last, open, high, low, prevClose, volume, adjClose, dividendAmount, splitCoeff);
                    if ~exist('histNew', 'var')
                        histNew = histAdd;
                    else
                        histNew = vertcat(histAdd, histNew); 
                    end
                end

                if state == 7
                	obj.histFull = histNew;
                    state = 9;
                elseif state == 8
                    obj.histAdd = histNew;
                    state = 10;
                end                
            end
        end
        
       function state = saveTablePage (obj, state)
           if namedConst.downloadVerbose
                fprintf('/s')
           end
           if state == 3
                priceFileName = [namedConst.histFolder obj.symbol '_' num2str(obj.timestampNum) '_' namedConst.pricePageEnd namedConst.pageExtension];
                writetable(obj.pricePage, priceFileName);
                optionFileName = [namedConst.histFolder obj.symbol '_' num2str(obj.timestampNum) '_' namedConst.optionPageEnd namedConst.pageExtension];
                writetable(obj.optionPage, optionFileName);
                state = state + 1;
           elseif state == 9 || state == 10
                if state == 10
                    % load histFull from file
                    histTableDs = tabularTextDatastore([namedConst.histFolder obj.symbol '_*_' namedConst.histEnd namedConst.pageExtension]);
                    histTable = readall(histTableDs);
                    % add timezone
                    histTable.timestamp = datetime(histTable.timestamp,'TimeZone','America/New_York');
                    % merge timetables 
                    obj.histFull = vertcat(obj.histAdd, histTable);
                    [uniqueTimestamps, idxTimestamps, idxUnique] = unique(obj.histFull.timestamp);
                    obj.histFull = obj.histFull(idxTimestamps,:);
                end
                histFileBase = [obj.symbol '_' num2str(obj.histTimestampNum) '_' namedConst.histEnd namedConst.pageExtension];
                histFileName = [namedConst.histFolder histFileBase];
                % delete old files
                histFile = dir([namedConst.histFolder obj.symbol '_*_' namedConst.histEnd namedConst.pageExtension]); 
                % don't delete if trying to write to same file later (this
                % causes permission denied)
                try
                    if ~strcmp(histFile.name, histFileBase)
                        delete(fullfile(histFile.folder, histFile.name));
                    end
                catch ME
					if namedConst.warnings
						warning(['Old hist files not deleted. Error: ' ME.message])
					end
                end
                % write new file
                try 
                    writetable(obj.histFull, histFileName);
                catch ME
					if namedConst.warnings
						warning(['Could not save file ' histFileName '. Error: ' ME.message])
					end
                end
                state = 11;
           end
        end
        
    end     
        
        
    methods (Static)
        % webread but retries on error
        function structDate = safeWebRead (varargin)
            if namedConst.downloadVerbose
                fprintf('/d');
            end
            i = 0;
            while 1
                try
                    structDate = webread(varargin{:});
                    break;
                catch ME
                    i = i + 1;
                    if i < downloader.downloadRetries
						if namedConst.warnings
							warning(['Failed to download, will retry. Error: ' ME.message])
						end
                    else 
                        retryStr = 'Retry now';
                        cancelStr = 'Cancel and show error';
                        qstring = ['Press retry once internet connection working. Error: ' ME.message];
                        title = 'Failed to download after max number of retries';
                        if strcmpi(questdlg(qstring,title,retryStr,cancelStr,retryStr), retryStr)
                            i = 0;
                        else
                            rethrow(ME)
                        end
                    end
                end
            end
        end
       
    end
    
end

