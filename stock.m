classdef stock < handle
    % handle might be necessary to reference from optionTable and
    % histTable classes (or use @)
    %STOCK Class with variables (including names of option tables) that can
    %instantia objects to get option or hist tables
    
    properties
        symbol;
        portfolio; % useful for intermarket spreads. Needed to get interest rate
%         correlationSpy; % should be used for intermarket spread and
%         portfolio risk (reduce with unit puts). Can be calculated given
%         enough hist data
        IVLevel = '';
        IVToHV = '';
        IVDirection = '';
        HVLevel = '';
        HVDirection = '';
        IntraMonthSkew = '';
        TermStructure = '';
        UnderlyingDirection = '';
    end
    
    
    methods
        function obj = stock (symbol, portfolio)
            fprintf('Constructing stock.\n')
            obj.symbol = symbol;
            obj.portfolio = portfolio;
        end
       
        % FIXME DEPRECIATED
        function stockSpec = getSpec (obj, volNrDays, varargin)
            [~, dividendData] = obj.getDividend ();
            if ~exist('volNrDays', 'var') || isempty(volNrDays)
                volNrDays = namedConst.defaultVolNrDays;
            end
            if ~isempty(dividendData)
                [type, amounts, dates] = dividendData{:};
                stockSpec = stockspec(obj.getPrice1dVar(['SD' num2str(volNrDays)], varargin{:}), obj.getPrice1dVar('last', varargin{:}), type, amounts, dates);
            else
                stockSpec = stockspec(obj.getPrice1dVar(['SD' num2str(volNrDays)], varargin{:}), obj.getPrice1dVar('last', varargin{:}));
                if isnan(stockSpec.Sigma)
                    error('sigma not calculated')
                end
            end
        end
        
        function filteredSpreads = filterSpreads(obj)
            cheatSheet = namedConst.cheatSheet();
            names = keys(cheatSheet);
            spreadTypes = values(cheatSheet);
            filteredSpreads = containers.Map();
            % filter out only spreads that match inputs (ie current market
            % conditions)
            for i = 1:numel(names)
                spread = spreadTypes{i};
                qualifies = true;
                qualifies = qualifies && (isempty(obj.IVLevel) || isempty(spread.IVLevel) || ~isempty(intersect(obj.IVLevel, spread.IVLevel)));
                qualifies = qualifies && (isempty(obj.IVToHV) || isempty(spread.IVToHV) || ~isempty(intersect(obj.IVToHV, spread.IVToHV)));
                qualifies = qualifies && (isempty(obj.IVDirection) || isempty(spread.IVDirection) || ~isempty(intersect(obj.IVDirection, spread.IVDirection)));
                qualifies = qualifies && (isempty(obj.HVLevel) || isempty(spread.HVLevel) || ~isempty(intersect(obj.HVLevel, spread.HVLevel)));
                qualifies = qualifies && (isempty(obj.HVDirection) || isempty(spread.HVDirection) || ~isempty(intersect(obj.HVDirection, spread.HVDirection)));
                qualifies = qualifies && (isempty(obj.UnderlyingDirection) || isempty(spread.UnderlyingDirection) || ~isempty(intersect(obj.UnderlyingDirection, spread.UnderlyingDirection)));
                qualifies = qualifies && (isempty(obj.IntraMonthSkew) || isempty(spread.IntraMonthSkew) || ~isempty(intersect(obj.IntraMonthSkew, spread.IntraMonthSkew)));
                qualifies = qualifies && (isempty(obj.TermStructure) || isempty(spread.TermStructure) || ~isempty(intersect(obj.TermStructure, spread.TermStructure)));
                if qualifies
                    filteredSpreads(names{i}) = spread;
                end
            end
        end
        
    end
    

    
end

