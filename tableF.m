classdef tableF < tableT
    % Contains operations that can be performed on an F shape (option2d + price1d + price2d + option2d') of
    % priceOptionTimeTable
    
    properties
        accessedTableF;
    end
    
    methods
        function obj = tableF (varargin)
            fprintf('Constructing tableF.\n')
            obj = obj@tableT(varargin{:});
            obj.accessedTableF = containers.Map();
        end
        
        % datetime or nrDays can be provided. If nrDays then rolling,
        % interpolated table
         function F = getF (obj, expDate, strike)
            obj.setAccessedTableF (expDate, strike);
            F = obj.accessedTableF (obj.expStrikeToStr (expDate, strike));
         end
         
         function F = loadFFromOption3d (obj, expDate, strike)
            option3d = obj.getOption3d();
            try
                expDate = datetime(expDate);
                useDate = 1;
            catch ME
                warning(['No datetime provided. Instead following number of days to expiration will be used: ' num2str(expDate) '. Error: ' ME.message])
                useDate = 0;
                nrDays = expDate;
            end
            switch numel(strike)
                case 0
                    F = option3d;
                case 1
                    F = option3d(option3d.strike == strike,:);
                case 2
                    F = option3d(option3d.strike >= strike(1) & option3d.strike <= strike(2),:);
                otherwise
                    F = option3d(ismember(option3d.strike, strike),:);
            end
            if useDate
                F = F(F.expDate == expDate, :);
                F = gather(F);
            else
                % for every unique timestamp in option3d
                F.daysToExp = calc.daysToExpiry (F);
                timestampGroups = findgroups(F.timestamp);            
                findNear = @(x) calc.findNearest (nrDays, x);
                nearestDays = splitapply(findNear, F.daysToExp, timestampGroups);
                [F, timestampGroups, nearestDays] = gather(F, timestampGroups, nearestDays);
                nearIdx = nearestDays(timestampGroups) == F.daysToExp;
                F = F(nearIdx, :);
            end
         end
        
         
         function setAccessedTableF (obj, expDate, strike)
            % check if accessed before
            str = obj.expStrikeToStr (expDate, strike);
            if ~isKey(obj.accessedTableF, str)
                obj.accessedTableF(str) =  obj.loadFFromOption3d (expDate, strike);
            end
         end  
        
         function updateAccessedTableF (obj, F, expDate, strike)
             str = obj.expStrikeToStr (expDate, strike);
             obj.accessedTableF(str) =  F;
         end
         
         function mergeF (obj, F, expDate, strike)
             % merge table with partial calc data with full table
         end
         
         function F = calcATMIVF (obj, expDate, strike)
             F = obj.getF (expDate, strike);
             % filter out everything fetched when market closed (as
             % these have 0 bid ask)
             F ((F.putBid == 0 & F.putAsk == 0) | (F.callBid == 0 & F.callAsk == 0), :) = [];
             F.riskFreeRate = repmat(obj.portfolio.getRiskFreeRate(), size(F,1),1);
             F.dividend = repmat(obj.getDividend(), size(F,1),1);
             F = calc.ATMIV (F);
         end
         
         function F = calcDeltaIVF (obj, delta, expDate, strike)

             if isscalar(expDate)
                volNrDays = expDate;
             else
                % FIXME hard to implement, workaround
                volNrDays = ceil(datenum(expDate) - today);
             end
             F = obj.calcHistVolF (volNrDays, strike);
             % filter out everything fetched when market closed (as
             % these have 0 bid ask)
             F ((F.putBid == 0 & F.putAsk == 0) | (F.callBid == 0 & F.callAsk == 0), :) = [];
             F.riskFreeRate = repmat(obj.portfolio.getRiskFreeRate(), size(F,1),1);
             F.dividend = repmat(obj.getDividend(), size(F,1),1);
             F = calc.deltaIVTable (delta, F);
         end
         
         function [callSkew, putSkew, FCallTimes, FPutTimes] = calcSkew(obj, delta, expDate, strike)
            F50 = obj.calcATMIVF (expDate, strike);
            
            FCallSkew = obj.calcDeltaIVF (delta, expDate, strike);
            [FCallTimes, F50Idx, FCallSkewIdx] = intersect(F50.Properties.RowTimes, FCallSkew.Properties.RowTimes);
            F50 = F50(F50Idx, :);
            FCallSkew = FCallSkew(FCallSkewIdx, :);
            callSkew = FCallSkew.callIV ./ F50.callIV;
            
            FPutSkew = obj.calcDeltaIVF (-delta, expDate, strike);
            [FPutTimes, F50Idx, FPutSkewIdx] = intersect(F50.Properties.RowTimes, FPutSkew.Properties.RowTimes);
            F50 = F50(F50Idx, :);
            FPutSkew = FPutSkew(FPutSkewIdx, :);
            putSkew = FPutSkew.putIV ./ F50.putIV;
         end
         
         function F = calcHistVolF (obj, nrDays, strike)
             if isempty(obj.getVarIfExist (['SD' num2str(nrDays)], obj.getPrice2d()))
                 obj.calcHistVolatility (nrDays);
             end   
             F = obj.getF (nrDays, strike);
             % set in F
             price2d = obj.getPrice2d();
             price2d = price2d(F.Properties.RowTimes, ['SD' num2str(nrDays)]);
             idxF = ismember(price2d.Properties.RowTimes, F.Properties.RowTimes);
             F = F(idxF, :);
             F.SD = price2d.(['SD' num2str(nrDays)]);
%              obj.updateAccessedTableF (F, nrDays, strike);
         end
        
         function [option2dVar, option2d] = getOption2dVar (obj, optionVar, varargin)
            [option2dVar, option2d] = getOption2dVar@tableT(obj, optionVar, varargin{:}); 
            if isempty(option2dVar) % throw error if not exist
                error(['Requested option2dVar ' optionVar ' does not exist in table'])
            end
         end
         
         function [price2dVar, price2d] = getPrice2dVar (obj, priceVar, varargin)
            [price2dVar, price2d] = getPrice2dVar@tableT(obj, priceVar, varargin{:}); % if download var requested just retrieve from superclass
            if isempty(price2dVar) % throw error if not exist
                error(['Requested price2dVar ' priceVar ' does not exist in table'])
            end
         end
         
          function [price1dVar, price1d] = getPrice1dVar (obj, priceVar, varargin)
            [price1dVar, price1d] = getPrice1dVar@tableT(obj, priceVar, varargin{:}); % if download var requested just retrieve from superclass
            if isempty(price1dVar) % throw error if not exist
                error(['Requested price1dVar ' priceVar ' does not exist in table'])
            end
         end
    end
    
    methods (Static)        
        function str = expStrikeToStr (expDate, strike)
             try
                datetime(expDate);
                str = datestr(expDate);
             catch 
                str = num2str(expDate);
             end
             str = [str, '_', num2str(strike)];
         end
    end
end

