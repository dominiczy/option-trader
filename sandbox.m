classdef sandbox < handle

    methods
        function dummy (obj, a, varargin)
            nargin
            obj.dummy2(varargin{:});
        end

        function dummy2 (obj, varargin)
            varargin{:};
        end
    end
end