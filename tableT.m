classdef tableT < tableI & tableH
    % Contains operations that can be performed on a T shape (option2d + price1d + price2d) of
    % priceOptionTimeTable
    
    methods
        function obj = tableT (varargin)
            fprintf('Constructing tableT.\n')
            obj = obj@tableI(varargin{:});
            obj = obj@tableH(varargin{:});
        end
        
       % GETTER overwrite
        function [option2dVar, option2d] = getOption2dVar (obj, optionVar, varargin)
            [option2dVar, option2d] = getOption2dVar@tableI(obj, optionVar, varargin{:}); 
            if isempty(option2dVar) % recalc if not exist
                obj.calcOptRealizedVol(varargin{:}); 
                [option2dVar, option2d] = getOption2dVar@priceOptionTimeTable(obj, optionVar, varargin{:}); 
            end
        end
        
        
        % this uses vol function from hist
        function calcOptRealizedVol (obj, varargin)
            fprintf('Executing %s: calcRealizedVol.\n', class(obj));
            expDates = obj.getOption2dVar('expDate', varargin{:});
            uniqueExpDates = unique (expDates);
            SD = zeros(numel(expDates),1);
%             ATR = SD;
            for dateNr = 1:numel(uniqueExpDates)
                 nrDays = ceil(datenum(uniqueExpDates(dateNr)) - datenum(obj.getTimestamp(varargin{:}))); % difference in days in whole days, ie if expiry is tomorrow, for any time today it gives 1
                 nrDays = max(namedConst.minVolNrDays, nrDays); 
                 if isempty(obj.getVarIfExist (['SD' num2str(nrDays)], obj.getPrice1d(varargin{:})))
                    obj.calcHistVolatility (nrDays);
                 end
                 indices = (expDates == uniqueExpDates(dateNr));
                 SD(indices) = obj.getPrice1dVar(['SD' num2str(nrDays)], varargin{:});
            end
            obj.setOption2dVar ('SD', SD, varargin{:});
            obj.calcSensRealized(varargin{:});
        end     
    end  
end

