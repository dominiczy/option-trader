classdef calc
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
    end
    
    methods (Static)
        function [callIV, putIV, daysToExp] = IV (table)
            tolerance = []; %1e-3;
            limit = []; % 200;
            daysToExp = calc.daysToExpiry (table);
            years = daysToExp / namedConst.daysPerYear;
            arg = {table.stockLast, table.strike, table.riskFreeRate, years};
            if ismember ('dividend', table.Properties.VariableNames)
                dividend = table.dividend;
            else
                dividend = [];
            end
            callIV = blsimpv(arg{:}, table.callMid, limit, dividend, tolerance, {'Call'});
            putIV = blsimpv(arg{:}, table.putMid, limit, dividend, tolerance, {'Put'});
         end
         
         function [callTheo, putTheo, callDelta, putDelta, gamma, callTheta, putTheta, vega] = sens (table, volatility, varargin)
%             years = (datenum(table.expDate) - datenum(obj.getTimestamp(varargin{:}))) / namedConst.daysPerYear;
            table.daysToExp = calc.daysToExpiry (table);
            years = table.daysToExp / namedConst.daysPerYear;
            if ismember ('dividend', table.Properties.VariableNames)
                dividend = table.dividend;
            else
                dividend = [];
            end
            if numel(volatility) == numel(years) % volatility is not scalar
                validIdx = ~isnan(volatility);
                table = table(validIdx, :);
                volatility = volatility(validIdx);
                years = years(validIdx);
                if ~isempty(dividend)
                    dividend = dividend(validIdx);
                end
            else
                validIdx = true(numel(years), 1);
            end
            callTheo = nan(numel(years),1);
            putTheo = callTheo;
            callDelta = callTheo;
            putDelta = callTheo;
            gamma = callTheo;
            callTheta = callTheo;
            putTheta = callTheo;
            vega = callTheo;
            arg = {table.stockLast, table.strike, table.riskFreeRate, years, volatility, dividend};
            [callTheo(validIdx), putTheo(validIdx)] = blsprice(arg{:});
            [callDelta(validIdx), putDelta(validIdx)] = blsdelta(arg{:});
            gamma(validIdx) = blsgamma(arg{:});
            [callTheta(validIdx), putTheta(validIdx)] = blstheta(arg{:});
            vega(validIdx) = blsvega(arg{:});
            % convert vega to movement per 1% vol change
            vega = vega / 100;
            % convert theta to days
            callTheta = callTheta / namedConst.daysPerYear;
            putTheta = putTheta / namedConst.daysPerYear;
        end
        
        function [callMid, putMid] = mid (table)
            callMid = (table.callBid + table.callAsk) / 2;
            putMid = (table.putBid + table.putAsk) / 2;
        end 
		
		
        % FIXME can be optimized using groups
        function forwardLevel = forwardLevel (table)
            expDates = table.expDate;
            callMid = table.callMid;
            putMid = table.putMid;
            strike = table.strike;
            forwardLevel = NaN(numel(expDates),1);
            uniqueExpDates = unique (expDates);
            timestamps = table.timestamp;
            uniqueTimestamps = unique(timestamps);
            for timestampNr = 1:numel(uniqueTimestamps)
                for dateNr = 1:numel(uniqueExpDates)
                    indicesDate = (timestamps == uniqueTimestamps(timestampNr)  & expDates == uniqueExpDates(dateNr));
                    [~, forwardIdx] = min(abs(callMid(indicesDate) - putMid(indicesDate)));  
                    thisStrike = strike(indicesDate);
                    forwardLevel(indicesDate) = thisStrike(forwardIdx);
                end
            end
        end
        
		% FIXME can be optimized using groups
        function atmLevel = ATMLevel (table)
            timestamps = table.timestamp;
            atmLevel = NaN(numel(timestamps),1);
            uniqueTimestamps = unique(timestamps);
            for timestampNr = 1:numel(uniqueTimestamps)
                indicesTime = (timestamps == uniqueTimestamps(timestampNr));
                [~, forwardIdx] = min(abs(table.strike(indicesTime) - table.stockLast(indicesTime)));  
                thisStrike = table.strike(indicesTime);
                atmLevel(indicesTime) = thisStrike(forwardIdx);
            end
        end
        
        function deltaLevel = deltaLevel (delta, table) 
            timestampExpDateGroups = findgroups(table.timestamp, table.expDate);            
            findNear = @(x) calc.findNearest (delta, x);
            if delta > 0
                deltaSelect = table.callDelta;
            else
                deltaSelect = table.putDelta;
            end
            nearestDelta = splitapply(findNear, deltaSelect, timestampExpDateGroups);
            deltaLevel = nearestDelta(timestampExpDateGroups);
        end
        
        function nearest = findNearest (value, searchArr)
            diff = searchArr - value;
            minDiff = min(abs(diff));
            minDiffMore = min(abs(diff + 0.00001));
            nearest = sign(minDiffMore - minDiff) .* minDiff + value;
        end
		
        
        function deltaTable = deltaTable (delta, table)
            [table.callTheo, table.putTheo, table.callDelta, table.putDelta, table.gamma, table.callTheta, table.putTheta, table.vega] = calc.sens (table, table.SD);
            deltaLevel = calc.deltaLevel (delta, table);
            if delta > 0
                deltaTable = table(table.callDelta == deltaLevel, :);
            else
                deltaTable = table(table.putDelta == deltaLevel, :);
            end
        end
        
        function deltaTable = deltaIVTable (delta, table)
            deltaTable = calc.deltaTable (delta, table);
            [deltaTable.callMid, deltaTable.putMid] = calc.mid (deltaTable);
            [deltaTable.callIV, deltaTable.putIV, deltaTable.daysToExp] = calc.IV (deltaTable);
            deltaTable.daysAgo = calc.daysAgo (deltaTable);
        end
        
        function atmTable = ATMTable (table, forward)
            if exist('forward', 'var') && ~isempty(forward) && forward
                table.forwardLevel = calc.forwardLevel (table);
                atmTable = table(table.strike == table.forwardLevel, :);
            else
                atmLevel = calc.ATMLevel (table);
                atmTable = table(table.strike == atmLevel, :);
            end
        end
        
        function weightedVega = weightedVega (table)
            % calc nr of dates until front month expiry (this will be taken
            % as base)
            daysToFrontMonth = calc.frontMonthDate(table.timestamp)' - datenum(table.timestamp);
            daysToExpiry = datenum(table.expDate) - datenum(table.timestamp);
            weightedVega = table.IVega .* sqrt(daysToFrontMonth ./ daysToExpiry);
        end
        
        function [callDollarDelta, putDollarDelta] = dollarDelta (table)
            callDollarDelta = table.ICallDelta .* table.stockLast;
            putDollarDelta = table.IPutDelta .* table.stockLast;
        end
        
        function monthlyExpDate = expDateMonthly (table)
            monthlyExpDate = (datenum(table.expDate) == transpose(getExpiryFri(table.expDate)));
        end
        
        function [callDelta, putDelta, callGamma, putGamma, callTheta, putTheta, callVega, putVega] = relGreeks (table)
            if ismember ('IPutDelta', table.Properties.VariableNames)
                putDelta = table.IPutDelta ./ table.putMid;
                putGamma = table.IGamma ./ table.putMid;
                putVega = table.IVega ./ table.putMid;
                putTheta = table.IPutTheta ./ table.putMid;
                callDelta = table.ICallDelta ./ table.callMid;
                callGamma = table.IGamma ./ table.callMid;
                callVega = table.IVega ./ table.callMid;
                callTheta = table.ICallTheta ./ table.callMid;
            else
                putDelta = table.putDelta ./ table.putMid;
                putGamma = table.gamma ./ table.putMid;
                putVega = table.vega ./ table.putMid;
                putTheta = table.putTheta ./ table.putMid;
                callDelta = table.callDelta ./ table.callMid;
                callGamma = table.gamma ./ table.callMid;
                callVega = table.vega ./ table.callMid;
                callTheta = table.callTheta ./ table.callMid;
            end
        end
        
        function date = frontMonthDate (nowDate)
           if exist('nowDate', 'var') && ~isempty(nowDate)
               nowDate = datenum(nowDate);
           else
               nowDate = today;
           end
           date = getExpiryFri(nowDate);
           if date <= nowDate
               date = getExpiryFri(addtodate(nowDate, 1, 'month'));
           end
       end
        
        function daysToExp = daysToExpiry (table)
            daysToExp = ceil(datenum(table.expDate - datenum(table.timestamp)));
        end
        
        function daysAgo = daysAgo (table)
            daysAgo = datenum(table.timestamp) - today;
        end
        
        function atmIVTable = ATMIV (table)
            atmIVTable = calc.ATMTable (table);
            [atmIVTable.callMid, atmIVTable.putMid] = calc.mid (atmIVTable);
            [atmIVTable.callIV, atmIVTable.putIV, atmIVTable.daysToExp] = calc.IV (atmIVTable);
            atmIVTable.daysAgo = calc.daysAgo (atmIVTable);
        end
    end
end

