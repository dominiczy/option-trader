classdef myPortfolio < handle
    %PORTFOLIO Summary of this class goes here
    %   to save to file use: save fileName objectName
    %   to load from file use: load fileName objectName
    
    properties
        stocks = containers.Map(); % cell array of stock objects, check where curly braces needed.
        myScheduler; % downloads new data for all stocks
        rateTable; % stores risk rate data
        positions;
        positionsNoVol;
        portfolioGreeks;
        portfolioGreeksNoVol;
    end
    
    properties (Constant)
        myStocks = {'AAPL' 'QQQ' 'EEM' 'FB' 'WMT' 'C' 'VZ' 'SPY' 'DIA' 'MU' 'BA' ...
            'XOM' 'SVXY' 'UVXY' 'VXX' 'VMAX' '^VIX' 'IWM' 'GLD' 'FXI' 'EWZ' 'AMZN' ...
            'GM' 'INTC' 'KO' 'PFE' 'SO' 'TGT' 'VALE' 'TWTR' 'NVDA' 'RAD' 'AMAT' 'JPM' 'SNAP' 'NFLX'}; % these will be updated with specified period   
        withoutOptions = {}
        interestUrl = 'https://www.treasury.gov/resource-center/data-chart-center/interest-rates/Pages/TextView.aspx?data=yield'
        interestTableNr = 58 % changed recently from 64, then 62, then 61
        interestRateDates = [30 90 180 360 2*360 3*360 5*360 7*360 10*360 20*360 30*360]
    end
    
    methods
        % calls constructors of all stocks if fromScratch=1, else should load
        % stocks objects from files
        function obj = myPortfolio (loadStocks)
            fprintf('Constructing myPortfolio. loadStocks = %d.\n', loadStocks)
            obj.updateInterest;
            if exist('loadStocks','var') && ~isempty(loadStocks) && loadStocks
                obj.loadStocks;
%                 obj.loadPositions;
                obj.startScheduler;
            end
        end
        
        function startScheduler (obj)
            fprintf('Executing %s: startScheduler.\n', class(obj))
            obj.myScheduler = scheduler(values(obj.stocks));
        end
        
        function loadStocks (obj)
            fprintf('Executing myPortfolio: fromScratch. Creating stocks from scratch.\n')
            for i = 1:numel(obj.myStocks)
                obj.addStock(obj.myStocks{i});
            end
        end
   
        function addStock (obj, symbol, varargin)
            fprintf('Executing myPortfolio: addStock %s.\n', symbol)
            if ismember(symbol, obj.withoutOptions)
                obj.stocks(symbol) = tableH (symbol, obj, varargin{:});
            else
                obj.stocks(symbol) = tableF (symbol, obj, varargin{:});
            end
        end
        
        % FIXME  low priority: add timestamp and save to file for historic data
        function updateInterest (obj)
            fprintf('Executing myPortfolio: updateInterest.\n')
            rateCells = getTableFromWeb_mod (obj.interestUrl, obj.interestTableNr);
            rateVars = genvarname(rateCells(1,:));
            rateCells = rateCells(2:end,:);
            rateTable = cell2table(rateCells);
            rateTable.Properties.VariableNames = rateVars;
            obj.rateTable = obj.formatRateTable (rateTable);
        end
        
        % load latest tastyworks positions from folder
        % add symbols if not existing yet
        % set spreads
        % get beta from somewhere
        % calculate portfolio greeks
        function loadPositions (obj)
            positionFiles = dir([namedConst.posFolder namedConst.twDesktopPositions '*']); 
            % sort by date created
            [~,idx] = sort([positionFiles.datenum]);
            % load latest
            latestPositionFile = positionFiles(idx(end));
            obj.positions = readtable([namedConst.posFolder latestPositionFile.name]);
            obj.positions.Properties.VariableNames{'x_'} = 'beta';
            obj.positions.Properties.VariableNames{'x_Delta'} = 'betaDollarDeltaPerSpy';
            spyQuote = obj.getQuote('SPY');
            obj.positions.betaDollarDelta = obj.positions.betaDollarDeltaPerSpy .* spyQuote;
            obj.positions.dollarDelta = obj.positions.betaDollarDelta ./ obj.positions.beta;
            obj.positions.underlyingLast = obj.positions.dollarDelta ./ obj.positions.Delta;
            obj.positions.betaDollarGammaPerSpy = obj.positions.beta .* obj.positions.Gamma .* obj.positions.underlyingLast / spyQuote;
            obj.positions.betaVega = obj.positions.Vega .* obj.positions.beta;
            obj.positions.symbol = cell(size(obj.positions,1), 1);
            for row = 1:size(obj.positions,1)  
                % get symbol
                symbolLong = obj.positions.Symbol{row};
                ind=find(symbolLong==' ');
                obj.positions.symbol{row} = symbolLong(1:ind(1)-1);
                % add symbols t myStocks if not existing
 
            end
            volProducts = {'VIX' 'UVXY' 'VXX' 'SVXY' 'XIV' 'VMIN' 'VMAX'};
            volIdx = ismember(obj.positions.symbol, volProducts);
            obj.positionsNoVol = obj.positions(~volIdx, :);
            obj.positions
            obj.calcGreeks();
        end
        
        function calcGreeks (obj)
            obj.portfolioGreeks = table;
            obj.portfolioGreeks.betaDollarDeltaPerSpy = nansum(obj.positions.betaDollarDeltaPerSpy);
            obj.portfolioGreeks.betaDollarGammaPerSpy = nansum(obj.positions.betaDollarGammaPerSpy);
            obj.portfolioGreeks.vega = nansum(obj.positions.Vega);
            obj.portfolioGreeks.theta = nansum(obj.positions.Theta);
            obj.portfolioGreeks
            obj.portfolioGreeksNoVol = table;
            obj.portfolioGreeksNoVol.betaDollarDeltaPerSpy = nansum(obj.positionsNoVol.betaDollarDeltaPerSpy);
            obj.portfolioGreeksNoVol.betaDollarGammaPerSpy = nansum(obj.positionsNoVol.betaDollarGammaPerSpy);
            obj.portfolioGreeksNoVol.vega = nansum(obj.positionsNoVol.Vega);
            obj.portfolioGreeksNoVol.theta = nansum(obj.positionsNoVol.Theta);
        end
        
      
        function riskFreeRate = getRiskFreeRate (obj)
            riskFreeRate = obj.rateTable.x3Mo(end);
        end
        
        function riskRateSpec = getRiskRateSpec (obj, varargin)
              % riskFreeRate
            riskData = table2array(obj.rateTable(end, 2:end));
            dayZero = obj.rateDayZero(varargin{:});
            riskDates = daysadd(dayZero, obj.interestRateDates, 2);

            riskCurve = IRDataCurve('Zero', dayZero, riskDates, riskData);
            riskRateSpec = riskCurve.toRateSpec(dayZero + 30 : 30 : obj.rateDayZero() + 365);
        end
        
        function saveToFile (obj, portfolioName)
            fprintf('Executing myPortfolio: saveToFile.\n')
            % save the updated portfolio under the same variable name
            S.(portfolioName) = obj;
            save(portfolioName, '-struct', 'S');
        end
    end
    
    methods (Static)
        function date = rateDayZero (timestamp)
            if exist('timestamp', 'var') && ~isempty(timestamp)
                date = busdate(timestamp, -1);
            else
                date = busdate(today, -1);
            end
        end
        
        function formattedRateTable = formatRateTable (rateTable)
            % convert cells to numbers
            temp=zeros(size(rateTable.x1Mo,1),size(rateTable.x1Mo,2));
            temp=str2double(rateTable.x1Mo);
            rateTable.x1Mo=temp/100;
            temp=str2double(rateTable.x3Mo);
            rateTable.x3Mo=temp/100;
            temp=str2double(rateTable.x6Mo);
            rateTable.x6Mo=temp/100;
            temp=str2double(rateTable.x1Yr);
            rateTable.x1Yr=temp/100;
            temp=str2double(rateTable.x2Yr);
            rateTable.x2Yr=temp/100;
            temp=str2double(rateTable.x3Yr);
            rateTable.x3Yr=temp/100;
            temp=str2double(rateTable.x5Yr);
            rateTable.x5Yr=temp/100;
            temp=str2double(rateTable.x7Yr);
            rateTable.x7Yr=temp/100;
            temp=str2double(rateTable.x10Yr);
            rateTable.x10Yr=temp/100;
            temp=str2double(rateTable.x20Yr);
            rateTable.x20Yr=temp/100;
            temp=str2double(rateTable.x30Yr);
            rateTable.x30Yr=temp/100;
            %  convert date
             i = 1;
             clear tempDateCall tempDatePut;
            while i <= length(rateTable.Date)
                tempDate(i,1) = datetime(rateTable.Date(i),'InputFormat','MM/dd/yy');    
                i = i + 1;
            end
            rateTable.Date=tempDate;
            formattedRateTable = rateTable;
        end
        
        function marketOpen = isMarketOpen ()
            marketOpen = false;
            if ~isweekend(datetime('now','TimeZone','America/New_York'))
                nowNY = datetime('now','TimeZone','America/New_York');
                if (nowNY >= myPortfolio.getMarketOpenTime()) && (nowNY <= myPortfolio.getMarketCloseTime)
                    marketOpen = true;
                end
            end
        end
        
        function marketOpenTime = getMarketOpenTime (date)
            if ~exist('date','var') || isempty(date)
                date = datetime('today','TimeZone','America/New_York');
            end
            date = dateshift(date, 'start', 'day');
            if isweekend(date)
                date = busdate(date, 'previous');
            end
            marketOpenTime = datetime(date,'TimeZone','America/New_York') + hours(9.5);
        end
        
        function marketCloseTime = getMarketCloseTime (date)
            if ~exist('date','var') || isempty(date)
                date = datetime('today','TimeZone','America/New_York');
            end
            date = dateshift(date, 'start', 'day');
            if isweekend(date)
                date = busdate(date, 'previous');
            end
            marketCloseTime = datetime(date,'TimeZone','America/New_York') + hours(16);
        end
        
        % get Quote from alphavantage
        function quote = getQuote (symbol)
            alphaVantageQueryUrlBaseIntraday = 'https://www.alphavantage.co/query?function=TIME_SERIES_INTRADAY&interval=1min&outputsize=compact&symbol=';
            queryUrl = [alphaVantageQueryUrlBaseIntraday symbol '&apikey=' namedConst.alphaVantageKey];
            options = weboptions('Timeout', 20);
            quoteStruct = webread(queryUrl, options);
            try
                quoteCells = struct2cell(quoteStruct.TimeSeries_1min_);
            catch ME
                ME
            end
            quote = str2num(quoteCells{1}.x4_Close);
        end
    end
end

