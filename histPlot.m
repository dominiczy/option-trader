classdef histPlot < plotObj
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        maxNrDays;
        histTable;
        maxVol = 0.3;
        minPrice;
        maxPrice;
        ivolatilityPlotMonths = [];
    end
    
    properties (Constant)
        % could do days with txt like in skewplot) 
        relAbsOpt = {'Relative (year)' 'Relative (day)' 'Absolute (day)'};
    end
    
    methods
        function obj = histPlot(stock, ivolPlotMonths, varargin)
            fprintf('Constructing histPlot.\n')
            obj = obj@plotObj(stock, varargin{:});
            obj.lbx = 'Days ago'; 
            obj.lby = {'Realized volatility' 'Stock price'}; 
            obj.traceIDs = {'SD' 'ATR' 'putIVatm' 'callIVatm' 'putSkew' 'callSkew' 'putIV10' 'callIV10' 'Price Stock'};
            obj.rightStart = numel(obj.traceIDs);
            if exist('ivolPlotMonths','var') && ~isempty(ivolPlotMonths)
                obj.ivolatilityPlotMonths = ivolPlotMonths;
            end
            if exist('stock','var') && ~isempty(stock)
                obj.setVars();
                obj.createPlot();
            end
        end
        
        function setVars (obj)
            obj.figName = [obj.stock.symbol ': Historical Volatility'];
            obj.maxNrDays = size(obj.stock.getPrice2dDaily(obj.timestamp), 1);
            close = obj.stock.getPrice2dDailyVar('last', obj.timestamp);
            obj.minPrice = min(close);
            obj.maxPrice = max(close);
        end
        
        function createPlot (obj)
            fprintf('Executing %s: createPlot.\n', class(obj))

            S.tr = obj.newPlt('xLim', [-namedConst.daysPerYear/6 0], 'xstring','sprintf("Date: %s",datestr(datenum(@XVAL+datenum(today))))');
            
            S.relAbs = plt('pop', obj.popupBottomLeftPosition, obj.relAbsOpt,'callbk',@obj.clb,'swap');
            S.nrDays  = plt('slider', obj.sliderLeftMidPosition, [namedConst.defaultVolNrDays namedConst.minVolNrDays obj.maxNrDays],'Nr of Days to average', @obj.clb, 2);
            txtPos = obj.textUnderLegendPosition;
            S.volText = text(txtPos(1), txtPos(2),'Vol text here!!','units','norm','horiz','center','color',[.2 .6 1]);

            set(gcf, 'user', S);
            obj.clb();    % initialize plot
			
            if ~isempty(obj.ivolatilityPlotMonths)
                figure('Name',[obj.stock.symbol ': Historical IV (' num2str(obj.ivolatilityPlotMonths) ' months)'],'NumberTitle','off')
                % FIXME months should depend on current view
                months = obj.ivolatilityPlotMonths;
                imageLink = ['http://www.ivolatility.com/nchart.j?charts=volatility&1=ticker*' obj.stock.symbol ',R*1,period*' num2str(months) ',all*4,schema*options_big&2=ticker*' obj.stock.symbol ',R*1,period*' num2str(months) ',schema*options_big_narrow&add=x:1']
                volFileName = 'volatility.gif';
                websave(volFileName,imageLink);
                imshow(volFileName);
            end
            
        end
        
        function clb(obj) % callback function for all objects
            S = get(gcf, 'user'); % retrieve config
            % read back popups
            yVar = plt('pop', S.relAbs);
            nrDays = plt('slider', S.nrDays);
            try
                obj.stock.getPrice2dDailyVar(['SD' num2str(nrDays)], obj.timestamp);
            catch % if error recalc
                obj.stock.calcHistVolatility(nrDays);
            end
            SDReturnsPerDay = obj.stock.getPrice2dDailyVar(['SDDaily' num2str(nrDays)], obj.timestamp);
            SDReturnsPerDayAbs = obj.stock.getPrice2dDailyVar(['SDDailyAbs' num2str(nrDays)], obj.timestamp);
            SDReturnsPerYear = obj.stock.getPrice2dDailyVar(['SD' num2str(nrDays)], obj.timestamp);
            ATR = obj.stock.getPrice2dDailyVar(['ATR' num2str(nrDays)], obj.timestamp);
            relATR = obj.stock.getPrice2dDailyVar(['relATR' num2str(nrDays)], obj.timestamp);
            relATRPerYear = obj.stock.getPrice2dDailyVar(['relATRPerYear' num2str(nrDays)], obj.timestamp);            
            dates = obj.stock.getDailyTimes (obj.timestamp);
            X = datenum(dates) - today;
            stockPrice = obj.stock.getPrice2dDailyVar('last', obj.timestamp);
            last = obj.stock.getPrice1dVar('last', obj.timestamp);
            switch yVar
                case 1 % rel year
                    SD = SDReturnsPerYear;
                    ATR = relATRPerYear;
                    factor = 1;
                    maxVol = obj.maxVol;
                case 2 % rel day
                    SD = SDReturnsPerDay;
                    ATR = relATR;
                    factor = 1 / sqrt(namedConst.tradingDaysPerYear);
                    maxVol = obj.maxVol / sqrt(namedConst.tradingDaysPerYear);
                case 3 % abs days
                    SD = SDReturnsPerDayAbs;
                    factor =  last / sqrt(namedConst.tradingDaysPerYear);
                    maxVol = obj.maxVol / sqrt(namedConst.tradingDaysPerYear) * stockPrice(1);
            end
            set(S.tr(1), 'x', X, 'y', SD);
            set(S.tr(2), 'x', X, 'y', ATR);
            set(S.tr(end), 'x', X, 'y', stockPrice,'Linestyle', '--');
            if ~obj.limsSet
                obj.limsSet = true;
                plt('cursor',-1, 'yLim',[0 maxVol], 'yLimR', [obj.minPrice obj.maxPrice]);
            end
            
             % get min max strikes over IV hist period
            histXMin = datenum(namedConst.oldestHistDate) - today;
            minHistStrike = min(stockPrice(X > histXMin));
            maxHistStrike = max(stockPrice(X > histXMin));
            % get or recalc table
            F = obj.stock.calcATMIVF (nrDays, [minHistStrike maxHistStrike]);
            
            set(S.tr(3), 'x', F.daysAgo, 'y', factor * F.putIV);
            set(S.tr(4), 'x', F.daysAgo, 'y', factor * F.callIV);
            
            delta = 0.10;
            [callSkew, putSkew, FCallTimes, FPutTimes] = obj.stock.calcSkew(delta, nrDays, []);
            set(S.tr(5), 'x', datenum(FPutTimes) - today, 'y', 0.1*putSkew, 'LineWidth', 0.3, 'Linestyle', ':');
            set(S.tr(6), 'x', datenum(FCallTimes) - today, 'y', 0.1*callSkew, 'LineWidth', 0.3, 'Linestyle', ':');

            F = obj.stock.calcDeltaIVF (-delta, nrDays, []);
            set(S.tr(7), 'x', F.daysAgo, 'y', factor * F.putIV, 'LineWidth', 0.3);
            F = obj.stock.calcDeltaIVF (delta, nrDays, []);
            set(S.tr(8), 'x', F.daysAgo, 'y', factor * F.callIV, 'LineWidth', 0.3);
%             set(S.volText,'string',prin('Vol (%d days) ~, SD Current %4W ~, Min %4W ~, Max %4W ~, Avg ??? ~, ATR Current %4W ~, Min %4W ~, Max %4W', nrDays, ??)
            sprintf('Calculation finished. Plot updated')
        end
    end
    
end

