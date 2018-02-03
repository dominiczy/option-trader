classdef (Abstract) plotObj < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        stock;
        timestamp = [];
        
        limsSet = false;
        figName;
        lbx;
        lby;
        traceIDs;
        rightStart;
        axisPosition = [.100 .882 .235 .100]
        plotPosition = [.125 .105 .800 .760]
        popupBottomLeftPosition = [.110 .710 .100 .200]
        popupTopLeftPosition = [.110 .880 .040 .070]
        popupTopRightPosition = [.310 .710 .024 .200]
        popupBottomRightPosition = [.310 .880 .024 .200]
        sliderLeftPosition = [.190 .946 .150     ]
        sliderLeftMidPosition = [.350 .946 .150     ]
        sliderMidPosition = [.510 .946 .150     ]
        sliderRightMidPosition = [.670 .946 .150     ]
        sliderRightPosition = [.830 .946 .150     ]
        textTopRightPosition = [0.9518  0.9777      ]
        textUnderLegendPosition = [-.09 .350          ]
        textBottomLeftPosition = [.350  -.100          ]
        textBottomRightPosition = [.610  -.100          ]
    end
    
    
    methods
        function obj = plotObj (stock, varargin)
            fprintf('Constructing plotObj.\n')
            obj.stock = stock;
            % find nearest timestamp in stock or leave empty if not provided
            if numel(varargin) > 0
                obj.timestamp = varargin{:};
            end
        end
        
        function tr = newPlt (obj, varargin)
            for i=1:2
                try
                    tr = plt(0,zeros(1,numel(obj.traceIDs)),'Right',obj.rightStart:numel(obj.traceIDs),...
                    'Options','Slider -Xlog -Ylog', 'TraceID', obj.traceIDs, 'FigName', obj.figName, 'LabelX', obj.lbx,'LabelY', obj.lby, 'xy', obj.plotPosition, 'AxisLink',0, varargin{:});
                    break;  
                catch ME
                    if (i == 1)
                        delete(namedConst.plotCfgFile);
                    else
                        rethrow(ME);
                    end
                end
            end
        end
    end
    
    methods (Abstract)
        clb (obj)
        createPlot(obj)
        setVars(obj, varargin)
    end
    
    methods (Static)
        function zeroValues = zeroCrossings (zeroArr, valArr)
            iL = find(diff(sign(zeroArr)));
            iR = iL + 1;
            yL = zeroArr(iL);
            yR = zeroArr(iR);
            i = iL + yL./(yL-yR);
            zeroValues = valArr(iL) + (i - iL) .* (valArr(iR) - valArr(iL));
        end
    end
    
end

