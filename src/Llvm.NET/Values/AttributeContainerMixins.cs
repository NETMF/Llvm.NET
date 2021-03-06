using System;
using System.Collections.Generic;
using System.Linq;

namespace Llvm.NET.Values
{
    // Provides a layer of simplicity and backwards compatibility for manipulating attributes on Values
    public static class AttributesMixins
    {
        public static bool Contains( this IAttributeCollection self, AttributeKind kind )
        {
            return self.Any( a => a.Kind == kind );
        }

        public static T AddAttributes<T>( this T self, FunctionAttributeIndex index, params AttributeKind[ ] values )
            where T : class, IAttributeContainer
        {
            if( self == null )
            {
                throw new ArgumentNullException( nameof( self ) );
            }

            if( values != null )
            {
                foreach( var kind in values )
                {
                    AttributeValue attrib = self.Context.CreateAttribute( kind );
                    if( self is IAttributeAccessor container )
                    {
                        container.AddAttributeAtIndex( index, attrib );
                    }
                    else
                    {
                        self.Attributes[ index ].Add( attrib );
                    }
                }
            }

            return self;
        }

        public static T AddAttribute<T>( this T self, FunctionAttributeIndex index, AttributeKind kind )
            where T : class, IAttributeContainer
        {
            if( self == null )
            {
                throw new ArgumentNullException( nameof( self ) );
            }

            AttributeValue attrib = self.Context.CreateAttribute( kind );
            if( self is IAttributeAccessor container )
            {
                container.AddAttributeAtIndex( index, attrib );
            }
            else
            {
                self.Attributes[ index ].Add( self.Context.CreateAttribute( kind ) );
            }

            return self;
        }

        public static T AddAttribute<T>( this T self, FunctionAttributeIndex index, AttributeValue attrib )
            where T : class, IAttributeContainer
        {
            if( self == null )
            {
                throw new ArgumentNullException( nameof( self ) );
            }

            if( self is IAttributeAccessor container )
            {
                container.AddAttributeAtIndex( index, attrib );
            }
            else
            {
                self.Attributes[ index ].Add( attrib );
            }

            return self;
        }

        public static T AddAttributes<T>( this T self, FunctionAttributeIndex index, params AttributeValue[ ] attributes )
            where T : class, IAttributeContainer
        {
            return AddAttributes( self, index, ( IEnumerable<AttributeValue> )attributes );
        }

        public static T AddAttributes<T>( this T self, FunctionAttributeIndex index, IEnumerable<AttributeValue> attributes )
            where T : class, IAttributeContainer
        {
            if( self == null )
            {
                throw new ArgumentNullException( nameof( self ) );
            }

            if( attributes != null )
            {
                foreach( var attrib in attributes )
                {
                    if( self is IAttributeAccessor container )
                    {
                        container.AddAttributeAtIndex( index, attrib );
                    }
                    else
                    {
                        self.Attributes[ index ].Add( attrib );
                    }
                }
            }

            return self;
        }

        public static T AddAttributes<T>( this T self, FunctionAttributeIndex index, IAttributeDictionary attributes )
            where T : class, IAttributeContainer
        {
            if( attributes == null )
            {
                return self;
            }

            return AddAttributes( self, index, attributes[ index ] );
        }

        public static T RemoveAttribute<T>( this T self, FunctionAttributeIndex index, AttributeKind kind )
            where T : class, IAttributeContainer
        {
            if( self == null )
            {
                throw new ArgumentNullException( nameof( self ) );
            }

            if( kind == AttributeKind.None )
            {
                return self;
            }

            if( self is IAttributeAccessor container )
            {
                container.RemoveAttributeAtIndex( index, kind );
            }
            else
            {
                IAttributeCollection attributes = self.Attributes[ index ];
                AttributeValue attrib = attributes.FirstOrDefault( a => a.Kind == kind );
                if( attrib != default( AttributeValue ) )
                {
                    attributes.Remove( attrib );
                }
            }

            return self;
        }

        public static T RemoveAttribute<T>( this T self, FunctionAttributeIndex index, string name )
            where T : class, IAttributeContainer
        {
            if( self == null )
            {
                throw new ArgumentNullException( nameof( self ) );
            }

            if( self is IAttributeAccessor container )
            {
                container.RemoveAttributeAtIndex( index, name );
            }
            else
            {
                IAttributeCollection attributes = self.Attributes[ index ];
                AttributeValue attrib = attributes.FirstOrDefault( a => a.Name == name );
                if( attrib != default( AttributeValue ) )
                {
                    attributes.Remove( attrib );
                }
            }

            return self;
        }
    }
}
