classdef spread < handle
    %spread Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        legs;
        stock;
        paidPrice;
        soldPrice;
        comment;
        idx = [];
        contractSize = namedConst.defaultContractSize; 
    end
    
    methods
        
        function obj = spread(stock, varargin)
            fprintf('Constructing spread.\n')
            obj.stock = stock;
            obj.loadSpread(varargin{:});
            obj.setLegs;
        end
        
        function loadSpread (obj, varargin)
            % scan stock.option2d for non zero quantities and return
            % reduced table
            allSpreads = obj.stock.getSpreads (varargin{:})
            % list those legs by comment, and one option for without
            % comment (these likely stem from skew plot)
            comments = unique(allSpreads.spreadComment(~cellfun('isempty', allSpreads.spreadComment))); 
            celldisp(comments)

            % ask user which one should be loaded
            i = input('Which spread number? 0 to select custom')
            if i == 0
                obj.idx = input('Array with indices:')
                spread = allSpreads(obj.idx, :);
                obj.comment = 'custom selection';
            else
                idx = find(strcmpi(allSpreads.spreadComment, comments{i}));
                % set comment accordingly
                spread = allSpreads(idx, :);
                obj.comment = spread.spreadComment{1};
                obj.paidPrice = spread.paidPrice(1);
                obj.soldPrice = spread.soldPrice(1);
            end
        end
        
        % GETTER to be used throughout the class
        function spreadTable = getTable (obj, varargin)  
            option2d = obj.stock.getOption2d (varargin{:});
            spreadTable = obj.reduceTable (option2d);
        end
        
        function [tableVar, table] = getTableVar (obj, varName, varargin)
            obj.stock.getOption2dVar (varName, varargin{:});
            table = obj.getTable (varargin{:});
            tableVar = table.(varName);
        end
        
        function spreadTable = reduceTable (obj, spreadTable, varargin)
            % select legs from stock.option2d with matching comment
            spreadComment = obj.stock.getOption2dVar ('spreadComment', varargin{:});
            if isempty(obj.idx)
                rows = find(strcmpi(spreadComment,obj.comment));
            else
                allSpreads = obj.stock.getSpreads (varargin{:});
                spread = allSpreads(obj.idx, :);
                rows = zeros(size(spreadTable, 1), 1);
                for i = 1:size(spread,1) % for each row, match with spreadTable
                    rows = rows | (spreadTable.expDate == spread.expDate(i) & spreadTable.strike == spread.strike(i));
                end
            end
            spreadTable = spreadTable(rows, :);
        end
        
        function spreadTable = view (obj, varargin)
            spreadTable = obj.stock.viewOption2d(varargin{:});
            spreadTable = obj.reduceTable (spreadTable);
        end
        
        function saveToFile (obj)
            spreadFileName = [namedConst.histFolder obj.stock.symbol '_' num2str(datenum(obj.stock.getTimestamp())) '_' namedConst.spreadEnd namedConst.pageExtension]
            spreadTable = timetable2table(obj.view ({'basics', 'spreadVars'}));
            writetable(spreadTable, spreadFileName);
        end
        
        function setComment (obj, comment)
            % set comment used for identification to obj and to
            % stock.option2d
            obj.stock.setOption2dVarFor ('spreadComment', comment, [], [], obj.comment);
            obj.comment = comment;
            % save to file with current timestamp
        end
        
        
        function buy (obj, price)
            obj.stock.setOption2dVarFor ('paidPrice', price, [], [], obj.comment);
            obj.paidPrice = price;
            obj.saveToFile();
        end
        
        function sell (obj, price)
            obj.stock.setOption2dVarFor ('soldPrice', price, [], [], obj.comment);
            obj.soldPrice = price;
            obj.saveToFile();
        end
        
        function clear (obj)
            % set quantities to zero in stock.option2d and clear object
            obj.stock.setOption2dVarFor ('putQuantity', 0, [], [], obj.comment);
            obj.stock.setOption2dVarFor ('callQuantity', 0, [], [], obj.comment);
            obj.stock.setOption2dVarFor ('spreadComment', '', [], [], obj.comment);
            obj.stock.setOption2dVarFor ('paidPrice', 0, [], [], obj.comment);
            obj.stock.setOption2dVarFor ('soldPrice', 0, [], [], obj.comment);
            obj.legs = [];
        end
        
        function setLegs (obj)
            fprintf('Executing %s: setLegs.\n', class(obj))
			minimalTable = timetable2table(obj.view({'basics'},{'putQuantity', 'callQuantity'}),'ConvertRowTimes',false);
			
            % minimalTable = table(fullTable.callQuantity, root, fullTable.strike, fullTable.expDate, fullTable.putQuantity);
            spreadCells = table2cell(minimalTable);
            for rowNr = 1:size(spreadCells, 1)
                legCells{rowNr, 3} = char(spreadCells{rowNr, 1});
                legCells{rowNr, 2} = num2str(spreadCells{rowNr, 2});
                % necessary for both calls and put on same option
                if (spreadCells{rowNr, 3} ~= 0) && (spreadCells{rowNr, 4} ~= 0)
                    legCells{rowNr, 1} = [num2str(spreadCells{rowNr, 3}) ' P, ' num2str(spreadCells{rowNr, 4}) ' C'];
                elseif spreadCells{rowNr, 3} ~= 0 
                    legCells{rowNr, 1} = [num2str(spreadCells{rowNr, 3}) ' P'];
                elseif spreadCells{rowNr, 4} ~= 0
                    legCells{rowNr, 1} = [num2str(spreadCells{rowNr, 4}) ' C'];
                end
            end
            obj.legs = join(legCells);
        end

        function askPrice = getAsk (obj, varargin)
            table = obj.getTable(varargin{:});
            askPrice = dot(table.callQuantity.*(table.callQuantity > 0), table.callAsk) + dot(table.callQuantity.*(table.callQuantity < 0), table.callBid) ...
                + dot(table.putQuantity.*(table.putQuantity > 0), table.putAsk) + dot(table.putQuantity.*(table.putQuantity < 0), table.putBid);
        end
        
        function bidPrice = getBid (obj, varargin)
            table = obj.getTable(varargin{:});
            bidPrice = dot(table.callQuantity.*(table.callQuantity < 0), table.callAsk) + dot(table.callQuantity.*(table.callQuantity > 0), table.callBid) ...
                + dot(table.putQuantity.*(table.putQuantity < 0), table.putAsk) + dot(table.putQuantity.*(table.putQuantity > 0), table.putBid);
        end
        
        function midPrice = getMid (obj, varargin)
            midPrice = (obj.getAsk(varargin{:}) + obj.getBid(varargin{:})) / 2;
        end
        
        function midPriceInclCommisions = getMidInclCommissions (obj, varargin)
            midPriceInclCommisions = obj.getMid(varargin{:}) + numel(obj.legs) * namedConst.commission / obj.contractSize;
        end
        
        function  [delta, gamma, vega, theta, theo] = getSens (obj, varargin)
            fprintf('Executing %s: getSens.\n', class(obj))
            % probe delta (this will force recalculation is not exists)
            obj.stock.getOption2dVar ('ICallDelta', varargin{:});
            
            table = obj.getTable(varargin{:});
            
            delta = dot(table.IPutDelta, table.putQuantity) + dot(table.ICallDelta, table.callQuantity);
            gamma = dot(table.IGamma, table.putQuantity) + dot(table.IGamma, table.callQuantity);
            vega = dot(table.IVega, table.putQuantity) + dot(table.IVega, table.callQuantity);
            theta = dot(table.IPutTheta, table.putQuantity) + dot(table.ICallTheta, table.callQuantity);
            theo = dot(table.putTheo, table.putQuantity) + dot(table.callTheo, table.callQuantity);
        end
        
        function [delta, gamma, theta, vega, theo] = getSensIf (obj, priceUnderlying, volatility, days, varargin)
            fprintf('Executing %s: getSensIf.\n', class(obj)) 
            
            % do per leg
            theo = zeros(1, max([size(priceUnderlying,2) size(volatility,2) size(days,2)]));
            delta = zeros(1, max([size(priceUnderlying,2) size(volatility,2) size(days,2)]));
            gamma = zeros(1, max([size(priceUnderlying,2) size(volatility,2) size(days,2)]));
            theta = zeros(1, max([size(priceUnderlying,2) size(volatility,2) size(days,2)]));
            vega = zeros(1, max([size(priceUnderlying,2) size(volatility,2) size(days,2)]));
            [expDates, table] = obj.getTableVar('expDate',varargin{:});
           

            daysZero = days;
            for i = 1:size(table, 1)
                days = daysZero + datenum(expDates(i)) - datenum(expDates(1));
                years = days / namedConst.daysPerYear;
                arg = {priceUnderlying, table.strike(i), obj.stock.portfolio.getRiskFreeRate(), years, volatility(i,:), obj.stock.getDividend()};
                [callTheo, putTheo] = blsprice(arg{:});
                theo = theo + table.putQuantity(i) * putTheo + table.callQuantity(i) * callTheo;
                [callDelta, putDelta] = blsdelta(arg{:});
                delta = delta + table.putQuantity(i) * putDelta + table.callQuantity(i) * callDelta;
                gamma = gamma + (table.putQuantity(i) + table.callQuantity(i)) * blsgamma(arg{:});
                [callTheta, putTheta] = blstheta(arg{:});
                theta = theta + table.putQuantity(i) * putTheta + table.callQuantity(i) * callTheta;
                vega = vega + (table.putQuantity(i) + table.callQuantity(i)) * blsvega(arg{:});
            end
            % convert vega to movement per 1% vol change
            vega = vega / 100;
            % convert theta to days
            theta = theta / namedConst.daysPerYear;
        end
        
        function marginReq = getMarginReq (obj, varargin)
            if obj.getMid() > 0 % long options
                marginReq = obj.getMid(varargin{:});
            else % short options
                [strikes, table] = obj.getTableVar ('strike', varargin{:});
                shortPutStrike = strikes(table.putQuantity < 0);
                longPutStrike = strikes(table.putQuantity > 0);
                if isempty(shortPutStrike)
                    putMargin = 0;
                else
                    putMargin = (longPutStrike - shortPutStrike) * table.putQuantity(table.putQuantity < 0);
                end
                shortCallStrike = strikes(table.callQuantity < 0);
                longCallStrike = strikes(table.callQuantity > 0);
                if isempty(shortCallStrike)
                    callMargin = 0;
                else
                    callMargin = (shortCallStrike - longCallStrike) * table.callQuantity(table.callQuantity < 0);
                end
                marginReq = max(putMargin, callMargin);
            end
            if isempty (marginReq) % for naked options
                marginReq = NaN;
            end
        end
        
        function maxLoss = getMaxLoss (obj, varargin)
            maxLoss = -obj.getMid(varargin{:}) - obj.getMarginReq(varargin{:});
        end
        
        function IVs = getIVs (obj, varargin)
            obj.stock.getOption2dVar('putIV', varargin{:});
            table = obj.getTable(varargin{:});
            IVs = zeros(size(table,1),1);         
            for i = 1:size(table,1)
                if table.putQuantity(i) == 0
                    IVs(i) = table.callIV(i);
                elseif table.callQuantity(i) == 0
                    IVs(i) = table.putIV(i);
                else
                    IVs(i) = (table.callIV(i) + table.putIV(i)) / 2;
                end
            end
        end
        
        function IVs = getIVsIf (obj, priceChange, factor, varargin)
            if ~exist('factor','var') || isempty(factor)
                factor = -1;
            end
            currentIVs = obj.getIVs(varargin{:});
            IVs = currentIVs + factor * priceChange;
            sd20 = obj.stock.getPrice2dVar('SD20', varargin{:});
            sdMin = min(sd20(sd20 > 0));
            IVs (IVs < sdMin) = sdMin;
        end
        
        function monteCarlo (obj, daysUntilSell, nrDays, patternDays, whichVol, varargin)
            reps = 10000;
            repsPattern = 10000;
            returns = obj.stock.getPrice2dDailyVar('dayToDayReturn', varargin{:});
            volDays = namedConst.defaultVolNrDays;
            
            currentPrice = obj.stock.getPrice1dVar('last', varargin{:})   
            currentSD = obj.stock.getPrice1dVar('SD20', varargin{:}) 
            currentIV = obj.getIVs(varargin{:})
            returnsZero =  returns(end-volDays+1:end);
            % slighlty inaccurate for shorter holding periods
            tradingDaysUntilSell = ceil(daysUntilSell * namedConst.tradingDaysPerYear / namedConst.daysPerYear);
            
            if exist('nrDays','var') && ~isempty(nrDays)
                returns = returns(end-nrDays+1:end);
            else
                nrDays = numel(returns);
            end           
            if nrDays > 0
                % use just data that matches simple pattern
                if exist('patternDays','var') && ~isempty(patternDays)
                    histPrice = obj.stock.getPrice2dDailyVar('adjClose', [], varargin{:});
                    if exist('nrDays','var') && ~isempty(nrDays)
                        histPrice = histPrice(end-nrDays+1:end);
                    end
                    histPriceActual = histPrice (patternDays+1:end-tradingDaysUntilSell+1);
                    histPriceDelayed = histPrice (1:end-patternDays-tradingDaysUntilSell+1);
                    if currentPrice > histPrice(end-patternDays)
                        % select all start days at peaks
                        possibleStartDays = histPriceActual > histPriceDelayed;
                    else
                        % select all non peak start days
                        possibleStartDays = histPriceActual < histPriceDelayed;
                    end
                    % add in removed part to get correct indices
                    possibleStartDays = [false(patternDays, 1); possibleStartDays; false(tradingDaysUntilSell - 1, 1)];
                    reps = repsPattern;
                    randStartDays = ceil((nrDays-1).*rand(1, reps));
                    randStartDays = intersect(randStartDays, find(possibleStartDays'));
                    reps = numel(randStartDays);
                    randDays = zeros(tradingDaysUntilSell, numel(randStartDays));
                    for i = 1:numel(randStartDays)
                        randDays(:,i) = [randStartDays(i):randStartDays(i)+tradingDaysUntilSell - 1];
                    end
                else % use all data
                    patternDays = 0;
                    randDays = ceil((nrDays-1).*rand(tradingDaysUntilSell, reps));
                end
                randReturns = returns(randDays);
            else % reference using normal dist  
                if nrDays == 0
                    sigma = mean(currentIV);
                else
                    sigma = currentSD;
                end
                randReturns = normrnd(0, sigma / sqrt(namedConst.tradingDaysPerYear), tradingDaysUntilSell, reps);
            end
            
            if exist('whichVol','var') && ~isempty(whichVol) && strcmpi(whichVol, 'SD')
                returnsZero = repmat(returnsZero, 1, reps);
                returnsForSdCalc = [returnsZero; randReturns];
                returnsForSdCalc = returnsForSdCalc(end-volDays+1:end, :);
                endVol = std(returnsForSdCalc, 0, 1);
                endVol = endVol * sqrt(namedConst.tradingDaysPerYear);
                endVol = repmat (endVol, numel(currentIV), 1);
            else
                % calc updated implied vol (rises 1 point with 1% drop)
                factor = -1;
                if exist('whichVol','var') && ~isempty(whichVol) && strcmpi(whichVol, 'InvIV')
                    factor = 1; 
                else
                    whichVol = 'IV';
                end
                currentIVs = repmat(currentIV, 1, reps);
                % this assumes skew curve just moves up and down with IV
                % changes
                % use implied weighted vega
                endVol = obj.getIVsIf(sum(randReturns, 1), factor, varargin{:});
            end
            meanEndVol = mean(endVol, 2)
            endPrice = currentPrice * exp(sum(randReturns, 1));
                
            figure('Name',['Price dist ' obj.stock.symbol ': ' num2str(daysUntilSell) ' daysUntilSell, ' num2str(nrDays)  ' day history, ' num2str(patternDays) ' day pattern; ' strjoin(obj.legs, '; ')],'NumberTitle','off')
            histfit(endPrice);
            pd = fitdist(endPrice','Normal');
            meanEndPrice = pd.mu
            title({['CurrentPrice ' num2str(currentPrice)], ['CurrentIV ' num2str(currentIV')],  ['MeanEndPrice ' num2str(meanEndPrice)], ['MeanEndVol ' num2str(meanEndVol')]})
            
            expDates = obj.getTableVar('expDate', varargin{:});
            uniqueExpDates = unique (expDates);
            daysTillExpNearNow = datenum(uniqueExpDates(1)) - datenum(obj.stock.getTimestamp(varargin{:}));
            daysTillExp = daysTillExpNearNow - daysUntilSell;

            [delta, gamma, theta, vega, theo] = obj.getSensIf (endPrice, endVol, daysTillExp, varargin{:});
            figure('Name',['PL dist ' obj.stock.symbol ': ' num2str(daysUntilSell) ' daysUntilSell, ' num2str(nrDays)  ' day history, ' num2str(patternDays) ' day pattern, volType ' whichVol '; '  strjoin(obj.legs, '; ')],'NumberTitle','off')
            PL = theo - obj.getMidInclCommissions(varargin{:});
            PoP = 100*numel(PL(PL > 0)) / numel(PL)
            histfit(PL);
            pd = fitdist(PL','Normal');
            expectedReturn = 100 * pd.mu
            expectedReturnPerDay = expectedReturn / tradingDaysUntilSell
            marginReq = 100 * obj.getMarginReq(varargin{:});
            returnOnMarginPerDayPct = 100 *expectedReturnPerDay / marginReq
            sdReturn = 100 * pd.sigma
            title({['PoP% ' num2str(PoP)], ['Expected return ' num2str(expectedReturn)], ['Per day ' num2str(expectedReturnPerDay) ', SD ' num2str(sdReturn) ')'], ['ReturnOnMarginPerDay% ' num2str(returnOnMarginPerDayPct) ' (margin ' num2str(marginReq) ')']})
        end
    end
    
end

