classdef tableI < priceOptionTimeTable
    % Contains operations that can be performed on an I shaped page (option2d + price1d) of
    % priceOptionTimeTable
    
    properties (Constant)
        stockBasics = {'stockLast' 'stockChg' 'stockVolume'}
        basics = {'expDate' 'strike'}
        putBasics = {'putBid' 'putAsk' 'putLast' 'putChg' 'putVol'}
        callBasics = {'callBid' 'callAsk' 'callLast' 'callChg' 'callVol'}
        greeks = {'IGamma' 'IVega'}
        putGreeks = {'putIV' 'putMid' 'putTheo' 'IPutDelta' 'IPutTheta'}
        callGreeks = {'callIV' 'callMid' 'callTheo' 'ICallDelta' 'ICallTheta'}
        spreadVars = {'putQuantity' 'callQuantity' 'spreadComment' 'paidPrice' 'soldPrice'} 
    end
    
    methods
        function obj = tableI (varargin)
            fprintf('Constructing tableI.\n')
            obj = obj@priceOptionTimeTable(varargin{:});
        end
        
        % GETTER overwrite
        function [option2dVar, option2d] = getOption2dVar (obj, optionVar, varargin)
            [option2dVar, option2d] = getOption2dVar@priceOptionTimeTable(obj, optionVar, varargin{:}); % if download var requested just retrieve from superclass
            if isempty(option2dVar) % recalc if not exist
				if ~strcmpi(optionVar, 'SD') % this case should be handled by superclass
					if ~ismember(optionVar, obj.spreadVars)
						obj.calcOptionVars(varargin{:}); % recalculate just for the date specified in timestamp. 
					else
						obj.setSpreads(obj.getSpreads(varargin{:}), varargin{:});
					end
				end
                [option2dVar, option2d] = getOption2dVar@priceOptionTimeTable(obj, optionVar, varargin{:}); % if download var requested just retrieve from superclass
            end
        end
        
        % option2d calculations
        function calcOptionVars (obj, varargin)
            fprintf('Executing %s: calcOptionVars.\n', class(obj))
            obj.calcDaysToExpiry(varargin{:});
            obj.calcAvgIV(varargin{:});
            obj.calcWeightedVega(varargin{:});
            obj.calcRelGreeks(varargin{:});
            obj.calcExpDateMonthly(varargin{:});
        end
        
        function calcDaysToExpiry (obj, varargin)
            fprintf('Executing %s: calcDaysToExpiry.\n', class(obj))
            obj.setOption2dVar('daysToExp', calc.daysToExpiry (obj.getOption2d(varargin{:})), varargin{:});
        end
        
        function calcForwardLevel (obj, varargin)
            fprintf('Executing %s: calcForwardLevel.\n', class(obj))
            obj.setOption2dVar('forwardLevel', calc.forwardLevel (obj.getOption2d(varargin{:})), varargin{:});
        end
        
         % return select nr of columns 
         function viewTable = viewOption2d(obj, views, columns, varargin)
             % fprintf('Executing %s: viewOption2d.\n', class(obj))
             viewTable = obj.getOption2d(varargin{:});
             % columns
             viewColumns = [];
             for i = 1:numel(views)
                 viewColumns = [viewColumns, obj.(views{i})];
             end
              if exist('columns', 'var') && ~isempty(columns)
                 viewColumns = [viewColumns, columns];
             end
             viewTable = viewTable(:, viewColumns);
         end
        
         % calc mid price
        function calcMidPrice (obj, varargin)
            fprintf('Executing %s: calcMidPrice.\n', class(obj));
            [callMid, putMid] = calc.mid (obj.getOption2d(varargin{:}));
%             putMid = (obj.getOption2dVar('putBid', varargin{:}) + obj.getOption2dVar('putAsk', varargin{:})) / 2;
%             callMid = (obj.getOption2dVar('callBid', varargin{:}) + obj.getOption2dVar('callAsk', varargin{:})) / 2;
            obj.setOption2dVar('putMid', putMid, varargin{:});
            obj.setOption2dVar('callMid', callMid, varargin{:});
        end

        
%         function optSpec = getPutSpec (obj, varargin)
%              optSpec    = cell(numel(obj.getOption2dVar('expDate', varargin{:})),1);
%              optSpec(:) = {'put'};
%         end
%         
%         function optSpec = getCallSpec (obj, varargin)
%              optSpec    = cell(numel(obj.getOption2dVar('expDate', varargin{:})),1);
%              optSpec(:) = {'call'};
%         end
        
        % calc IV and add to optionTable
%         function calcIV (obj, varargin)
%             fprintf('Executing %s: calcIV.\n', class(obj))
%             % first puts
%             obj.calcMidPrice(varargin{:});
%             putArg = {obj.portfolio.getRiskRateSpec(varargin{:}), obj.getSpec([], varargin{:}), obj.getSettleDate(varargin{:}), ...
%                 obj.getOption2dVar('expDate', varargin{:}), obj.getPutSpec(varargin{:}), obj.getOption2dVar('strike', varargin{:}), obj.getOption2dVar('putMid', varargin{:})};
%             callArg = putArg; 
%             callArg{5} = obj.getCallSpec(varargin{:});
% 			callArg{7} = obj.getOption2dVar('callMid', varargin{:});
% 			obj.setOption2dVar('putIV', impvbybls(putArg{:}), varargin{:});
%             obj.setOption2dVar('callIV', impvbybls(callArg{:}), varargin{:});
%         end
        

         % by default, calculates for each expiry, weighted with volume
        function calcAvgIV (obj, varargin)
            fprintf('Executing %s: calcAvgIV.\n', class(obj))
            obj.calcIV (varargin{:});
            obj.calcSensImplied (varargin{:});
            obj.calcForwardLevel (varargin{:});
            riskFreeRate = obj.portfolio.getRiskFreeRate();
%             weight = namedConst.avgIVweight;
            putWeight = obj.getOption2dVar('IVega', varargin{:});
            callWeight = obj.getOption2dVar('IVega', varargin{:});
            expDates = obj.getOption2dVar('expDate', varargin{:});
            callMid = obj.getOption2dVar('callMid', varargin{:});
            callBid = obj.getOption2dVar('callBid', varargin{:});
            putMid = obj.getOption2dVar('putMid', varargin{:});
            putBid = obj.getOption2dVar('putBid', varargin{:});
            strike = obj.getOption2dVar('strike', varargin{:});
            forwardLevels = obj.getOption2dVar('forwardLevel', varargin{:});
            uniqueExpDates = unique (expDates);
            avgIV = NaN(numel(expDates),1);
            avgPutIV = avgIV;
            avgCallIV = avgIV;
            atmPutIV = avgIV;
            atmCallIV = avgIV;
            vixIV = avgIV;
            putIV = obj.getOption2dVar('putIV', varargin{:});
            callIV = obj.getOption2dVar('callIV', varargin{:});
            for dateNr = 1:numel(uniqueExpDates)
                indicesDate = (expDates == uniqueExpDates(dateNr));
                indicesDateNrs = find(indicesDate);
                if numel(indicesDateNrs) < 3
                    continue
                end
                % vix calculation
                timeToExp = (datenum(uniqueExpDates(dateNr)) - datenum(obj.getTimestamp(varargin{:}))) / namedConst.daysPerYear;
%                 [~, forwardIdx] = min(abs(callMid(indicesDate) - putMid(indicesDate)));  
                thisStrike = strike(indicesDate);
                forwardLevel = forwardLevels(indicesDateNrs(1));
                forwardIdx = find(thisStrike == forwardLevel);
                if forwardIdx < 2
                    continue
                end
                strikeLimit = thisStrike(forwardIdx - 1);
 
                contribution = 0;
%                 avgPutContribution = 0;
%                 avgCallContribution = 0;
%                 idxCalls = [];
%                 idxPuts = [];
                % calls
                for i = min(indicesDateNrs) + forwardIdx-1 : max(indicesDateNrs)
                    if callBid(i) == 0
                        if callBid(i-1) == 0
                            break
                        else
                            continue
                        end
                    end
                    if i == max(indicesDateNrs)
                        deltaStrike = strike(i) - strike(i-1);
                    elseif i == min(indicesDateNrs)
                        deltaStrike = strike(i + 1) - strike(i);
                    else
                        deltaStrike = (strike(i + 1) - strike(i - 1)) / 2;
                    end
%                     idxCalls = [idxCalls; i];
                    contribution = contribution + deltaStrike / strike(i)^2 * exp(riskFreeRate * timeToExp) * callMid(i);
%                     avgCallContribution = avgCallContribution + callIV(i) * callWeight(i);
                end   
                % puts
                for i = min(indicesDateNrs) + forwardIdx-1 :-1: min(indicesDateNrs)
                    if putBid(i) == 0
                        if putBid(i+1) == 0
                            break
                        else
                            continue
                        end
                    end
                    if i == min(indicesDateNrs)
                        deltaStrike = strike(i + 1) - strike(i);
                    elseif i == max(indicesDateNrs)
                        deltaStrike = strike(i) - strike(i-1);
                    else
                        deltaStrike = (strike(i + 1) - strike(i - 1)) / 2;
                    end
%                     idxPuts = [idxPuts; i];
                    contribution = contribution + deltaStrike / strike(i)^2 * exp(riskFreeRate * timeToExp) * putMid(i);
%                     avgPutContribution = avgPutContribution + putIV(i) * putWeight(i);
                end 
                vixIV(indicesDate) = sqrt(2 / timeToExp * contribution - 1 / timeToExp * (forwardLevel / strikeLimit - 1)^2);
%                 avgPutIV(indicesDate) = avgPutContribution / sum(putWeight(idxPuts));
%                 avgCallIV(indicesDate) = avgCallContribution / sum(callWeight(idxCalls));
%                 avgIV(indicesDate) = (avgPutContribution + avgCallContribution) / (sum(putWeight(idxPuts)) + sum(callWeight(idxCalls)));
                % exclude NaN IVs
                indicesDatePut = indicesDate & ~isnan(putIV) & putIV ~= 0; % & strike <= strikeLimit;
                indicesDateCall = indicesDate & ~isnan(callIV) & callIV ~= 0; % & strike >= strikeLimit; 
                avgIV(indicesDate) = (dot(putIV(indicesDatePut), putWeight(indicesDatePut)) + dot(callIV(indicesDateCall), ...
                callWeight(indicesDateCall))) / (sum(putWeight(indicesDatePut)) + sum(callWeight(indicesDateCall)));
                avgPutIV(indicesDate) = dot(putIV(indicesDatePut), putWeight(indicesDatePut)) / sum(putWeight(indicesDatePut));
                avgCallIV(indicesDate) = dot(callIV(indicesDateCall), callWeight(indicesDateCall)) / sum(callWeight(indicesDateCall));
                atmPutIV(indicesDate) = putIV(min(indicesDateNrs) + forwardIdx-1);
                atmCallIV(indicesDate) = callIV(min(indicesDateNrs) + forwardIdx-1);
            end
            obj.setOption2dVar('vixIV', vixIV, varargin{:});
            obj.setOption2dVar('avgIV', avgIV, varargin{:});
            obj.setOption2dVar('avgPutIV', avgPutIV, varargin{:});
            obj.setOption2dVar('avgCallIV', avgCallIV, varargin{:});
            obj.setOption2dVar('atmPutIV', atmPutIV, varargin{:});
            obj.setOption2dVar('atmCallIV', atmCallIV, varargin{:});
        end
        
        function [IV, callIV, putIV] = getIV (obj, nrDays, varargin)
            if ~exist('nrDays', 'var') || isempty(nrDays)
                nrDays = namedConst.defaultVolNrDays;
            end
            daysToExp = obj.getOption2dVar('daysToExp', varargin{:});
            atmPutIV = obj.getOption2dVar('atmPutIV', varargin{:});
            atmCallIV = obj.getOption2dVar('atmCallIV', varargin{:});
            daysDiff = daysToExp - nrDays;
            beforeDays = max(daysDiff(daysDiff < 0)) + nrDays;
            afterDays = min(daysDiff(daysDiff > 0)) + nrDays;
            if min(abs(daysDiff)) == 0 || isempty(beforeDays) || isempty(afterDays) 
                % there is an expDate at nrDays (or nrDays exceeds min or
                % max)
                if min(abs(daysDiff)) == 0
                    compareWith = nrDays;
                elseif isempty(beforeDays)
                    compareWith = afterDays;
                elseif isempty(afterDays)
                    compareWith = beforeDays;
                end
                putIV = atmPutIV(daysToExp == compareWith);
                putIV = putIV(1);
                callIV = atmCallIV(daysToExp == compareWith);
                callIV = callIV(1);
            else % need to select date before and after
                putIVBefore = atmPutIV(daysToExp == beforeDays);
                putIVAfter = atmPutIV(daysToExp == afterDays);
                callIVBefore = atmCallIV(daysToExp == beforeDays);
                callIVAfter = atmCallIV(daysToExp == afterDays);
                putIV = interp1([beforeDays afterDays], [putIVBefore(1) putIVAfter(1)], nrDays);
                callIV = interp1([beforeDays afterDays], [callIVBefore(1) callIVAfter(1)], nrDays);
            end
            IV = (putIV + callIV) / 2;
        end
        
        function option2dFront = getOption2dFront (obj, varargin)
            option2d = obj.getOption2d(varargin{:});
            option2dFront = option2d(datenum(option2d.expDate) == floor(calc.frontMonthDate(obj.getTimestamp(varargin{:}))),:);
        end
        
        % calc greeks and theoretical price and add to optionTable
%         function calcSens (obj, varargin)   
%             fprintf('Executing %s: calcSens.\n', class(obj));
% 
%             %  first puts         
%             % FIXME in getSpec we might want to use the nr of days until
%             % expiration. However difficult to implement since only one
%             % spec can be provided. Alternatively do on a per expDate basis
%             % (probably slower)
%             putArg = {obj.portfolio.getRiskRateSpec(varargin{:}),  obj.getSpec([], varargin{:}), obj.getSettleDate(varargin{:}), obj.getOption2dVar('expDate', varargin{:}), ...
%                 obj.getPutSpec(varargin{:}), obj.getOption2dVar('strike', varargin{:})};
%             callArg = putArg; 
%             callArg{5} = obj.getCallSpec(varargin{:});
%             [putDelta, gamma, vega, putLambda, putRho, putTheta, putTheo] = optstocksensbybls(putArg{:}, 'OutSpec', 'All');
%             % now calls
%             [callDelta, ~, ~, callLambda, callRho, callTheta, callTheo] = optstocksensbybls(callArg{:}, 'OutSpec', 'All');
%             % convert vega to movement per 1% vol change
%             vega = vega / 100;
%             % convert theta to days
%             putTheta = putTheta / namedConst.daysPerYear;
%             callTheta = callTheta / namedConst.daysPerYear;
%             
%             obj.setOption2dVar('putDelta', putDelta, varargin{:});
%             obj.setOption2dVar('gamma', gamma, varargin{:});
%             obj.setOption2dVar('vega', vega, varargin{:});
%             obj.setOption2dVar('putLambda', putLambda, varargin{:});
%             obj.setOption2dVar('putRho', putRho, varargin{:});
%             obj.setOption2dVar('putTheta', putTheta, varargin{:});
%             obj.setOption2dVar('putTheo', putTheo, varargin{:});
%             obj.setOption2dVar('callDelta', callDelta, varargin{:});
%             obj.setOption2dVar('callLambda', callLambda, varargin{:});
%             obj.setOption2dVar('callRho', callRho, varargin{:});
%             obj.setOption2dVar('callTheta', callTheta, varargin{:});
%             obj.setOption2dVar('callTheo', callTheo, varargin{:});
%         end
        
   
        function calcSensRealized (obj, varargin)
            fprintf('Executing %s: calcSensRealized.\n', class(obj));
            table = obj.getOption2d(varargin{:});
            volatility = obj.getOption2dVar('SD', varargin{:});
            [callTheo, putTheo, callDelta, putDelta, gamma, callTheta, putTheta, vega] = obj.calcSens (table, volatility, varargin{:});
            obj.setOption2dVar('putDelta', putDelta, varargin{:});
            obj.setOption2dVar('gamma', gamma, varargin{:});
            obj.setOption2dVar('vega', vega, varargin{:});
            obj.setOption2dVar('putTheta', putTheta, varargin{:});
            obj.setOption2dVar('putTheo', putTheo, varargin{:});
            obj.setOption2dVar('callDelta', callDelta, varargin{:});
            obj.setOption2dVar('callTheta', callTheta, varargin{:});
            obj.setOption2dVar('callTheo', callTheo, varargin{:});
        end
        
        function calcSensImplied (obj, varargin)
            fprintf('Executing %s: calcSensImplied.\n', class(obj));
            table = obj.getOption2d(varargin{:});
            volatility = obj.getOption2dVar('putIV', varargin{:});
            [~, ~, ~, putDelta, gamma, ~, putTheta, vega] = obj.calcSens (table, volatility, varargin{:});
            volatility = obj.getOption2dVar('callIV', varargin{:});
            [~, ~, callDelta, ~, ~, callTheta, ~, ~] = obj.calcSens (table, volatility, varargin{:});
            obj.setOption2dVar('IPutDelta', putDelta, varargin{:});
            obj.setOption2dVar('IGamma', gamma, varargin{:});
            obj.setOption2dVar('IVega', vega, varargin{:});
            obj.setOption2dVar('IPutTheta', putTheta, varargin{:});
            obj.setOption2dVar('ICallDelta', callDelta, varargin{:});
            obj.setOption2dVar('ICallTheta', callTheta, varargin{:});
        end
        
        function [callTheo, putTheo, callDelta, putDelta, gamma, callTheta, putTheta, vega] = calcSens (obj, table, volatility, varargin)
            fprintf('Executing %s: calcSens.\n', class(obj));
			obj.calcRiskFreeRate(varargin{:});
            obj.calcDividend(varargin{:});
			[callTheo, putTheo, callDelta, putDelta, gamma, callTheta, putTheta, vega] = calc.sens (table, volatility, varargin{:});
        end
        
        function calcIV (obj, varargin)
            fprintf('Executing %s: calcIV.\n', class(obj));
            obj.calcMidPrice(varargin{:});
			obj.calcRiskFreeRate(varargin{:});
            obj.calcDividend(varargin{:});
            [callIV, putIV] = calc.IV (obj.getOption2d(varargin{:}));
            obj.setOption2dVar('putIV', putIV, varargin{:});
            obj.setOption2dVar('callIV', callIV, varargin{:});
        end
		
        function setOption2dVarScalar (obj, var, value, varargin)
            reps = size(obj.getOption2d(varargin{:}),1);
            value = repmat(value, reps,1);
            obj.setOption2dVar(var, value, varargin{:});
        end
        
		function calcRiskFreeRate (obj, varargin)
			% we could calculate from the risk curve for various exp dates instead
			obj.setOption2dVarScalar('riskFreeRate', obj.portfolio.getRiskFreeRate(), varargin{:});
        end

        function calcDividend (obj, varargin)
            obj.setOption2dVarScalar('dividend', obj.getDividend(), varargin{:});
        end
        
        
         % calc dollar delta
        % $delta= (contract size x point value)/ 100
        function calcDollarDelta (obj, varargin)
            fprintf('Executing %s: calcDollarDelta.\n', class(obj));
            [callDollarDelta, putDollarDelta] = calc.dollarDelta (obj.getOption2d(varargin{:}));   
            obj.setOption2dVar('putDollarDelta', putDollarDelta, varargin{:});
            obj.setOption2dVar('callDollarDelta', callDollarDelta, varargin{:});
        end
        
        % calc weighted vega
        % Weighted vega = sqrt(base/days)*vega
        function calcWeightedVega (obj, varargin)
            fprintf('Executing %s: calcWeightedVega.\n', class(obj));
            obj.getOption2dVar ('IVega', varargin{:});
            obj.setOption2dVar( 'weightedVega', calc.weightedVega(obj.getOption2d(varargin{:})), varargin{:});
        end
        
        % calc greeks relative to price
        function calcRelGreeks (obj, varargin)
            [callDelta, putDelta, callGamma, putGamma, callTheta, putTheta, callVega, putVega] = calc.relGreeks (obj.getOption2d(varargin{:}));
            obj.setOption2dVar('putDeltaRel', putDelta);
            obj.setOption2dVar('putGammaRel', putGamma);
            obj.setOption2dVar('putVegaRel', putVega);
            obj.setOption2dVar('putThetaRel', putTheta);
            obj.setOption2dVar('callDeltaRel', callDelta);
            obj.setOption2dVar('callGammaRel', callGamma);
            obj.setOption2dVar('callVegaRel', callVega);
            obj.setOption2dVar('callThetaRel', callTheta);
        end
        
        function calcExpDateMonthly (obj, varargin)
            fprintf('Executing %s: expDateMonthly.\n', class(obj));
            obj.setOption2dVar('monthlyExpDate', calc.expDateMonthly (obj.getOption2d(varargin{:})), varargin{:});
        end
        
        % FIXME low priority: needs time map
        function date = getSettleDate (obj, varargin)
            date = obj.getNonDailyTimestamp(varargin{:});
        end
       
        function surface = volSurf (obj, varargin)
            surface = VolSurface(obj.getPrice1dVar('last', varargin{:}), obj.portfolio.getRiskFreeRate(), obj.getOption2dVar('daysToExp', varargin{:}) / namedConst.tradingDaysPerYear, obj.getOption2dVar('strike', varargin{:}), obj.getOption2dVar('callMid', varargin{:}));
        end
    end
   

end

